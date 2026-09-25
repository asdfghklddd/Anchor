import AnchorCore
@preconcurrency import CoreBluetooth
import CryptoKit
import Foundation

public enum AnchorBluetoothService {
    public static var uuid: CBUUID { CBUUID(string: "A11C0001-4E43-484F-5220-414E43484F52") }
    public static var pairingCredentialUUID: CBUUID {
        CBUUID(string: "A11C0002-4E43-484F-5220-414E43484F52")
    }
    public static var eventTransferUUID: CBUUID {
        CBUUID(string: "A11C0003-4E43-484F-5220-414E43484F52")
    }
}

#if os(macOS)
public final class AnchorProximityAdvertiser: NSObject, CBPeripheralManagerDelegate, AnchorEventTransport, @unchecked Sendable {
    private typealias OperationContinuation = CheckedContinuation<Void, any Error>

    private struct PendingDelivery {
        let continuation: OperationContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    private struct OutboundTransfer {
        let central: CBCentral
        let chunks: [Data]
        var nextIndex: Int
    }

    private static let operationTimeout: TimeInterval = 10

    private let deviceID: UUID
    private let pairingToken: AnchorBluetoothPairingToken
    private let identityStore: PairingIdentityStore
    private var pairingChallenge: Data
    private var manager: CBPeripheralManager?
    private var pairingCharacteristic: CBMutableCharacteristic?
    private var eventCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [UUID: CBCentral] = [:]
    private var peerIDs: [UUID: UUID] = [:]
    private var assemblers: [UUID: AnchorBluetoothTransferAssembler] = [:]
    private var outboundTransfers: [OutboundTransfer] = []
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var replayWindow = LinkReplayWindow()
    private var eventApplicationTask: Task<Void, Never>?
    private var dataLinkState = ConnectionState.unavailable

    public var onEvent: (@Sendable (EventEnvelope) async throws -> Void)?
    public var onCurrentProcessSnapshot: (@Sendable () async throws -> CurrentProcessSnapshot)?
    public var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    public init(
        deviceID: UUID,
        pairingToken: AnchorBluetoothPairingToken,
        identityStore: PairingIdentityStore = PairingIdentityStore()
    ) {
        self.deviceID = deviceID
        self.pairingToken = pairingToken
        self.identityStore = identityStore
        pairingChallenge = Self.makePairingChallenge(secret: pairingToken.current())
    }

    public func start() {
        guard manager == nil else { return }
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    public func stop() {
        manager?.stopAdvertising()
        manager?.removeAllServices()
        pairingCharacteristic = nil
        eventCharacteristic = nil
        subscribedCentrals.removeAll()
        peerIDs.removeAll()
        assemblers.removeAll()
        outboundTransfers.removeAll()
        eventApplicationTask?.cancel()
        eventApplicationTask = nil
        failAllDeliveries(with: CancellationError())
        setDataLinkState(.unavailable)
        manager = nil
    }

    public func send(_ event: EventEnvelope) async throws {
        try await withCheckedThrowingContinuation { (continuation: OperationContinuation) in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard pendingDeliveries[event.id] == nil else {
                    continuation.resume(throwing: AnchorLinkError.operationInProgress)
                    return
                }
                do {
                    let (central, key) = try authenticatedCentral()
                    let timeout = DispatchWorkItem { [weak self] in
                        self?.finishDelivery(
                            event.id,
                            with: .failure(AnchorLinkError.acknowledgementTimedOut)
                        )
                    }
                    pendingDeliveries[event.id] = PendingDelivery(
                        continuation: continuation,
                        timeoutWorkItem: timeout
                    )
                    try enqueue(
                        LinkPayload(kind: .event, event: event),
                        key: key,
                        central: central
                    )
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Self.operationTimeout,
                        execute: timeout
                    )
                } catch {
                    pendingDeliveries[event.id] = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth advertiser state \(peripheral.state.rawValue)")
        #endif
        guard peripheral.state == .poweredOn else {
            peripheral.stopAdvertising()
            setDataLinkState(peripheral.state == .unauthorized ? .permissionDenied : .unavailable)
            return
        }
        let pairingCharacteristic = CBMutableCharacteristic(
            type: AnchorBluetoothService.pairingCredentialUUID,
            properties: [.read],
            value: nil,
            // The credential is a rotating bootstrap token. Task data uses the
            // separately persisted peer key and authenticated encryption.
            permissions: [.readable]
        )
        let eventCharacteristic = CBMutableCharacteristic(
            type: AnchorBluetoothService.eventTransferUUID,
            properties: [.write, .indicate],
            value: nil,
            permissions: [.writeable]
        )
        let service = CBMutableService(type: AnchorBluetoothService.uuid, primary: true)
        service.characteristics = [pairingCharacteristic, eventCharacteristic]
        self.pairingCharacteristic = pairingCharacteristic
        self.eventCharacteristic = eventCharacteristic
        peripheral.removeAllServices()
        peripheral.add(service)
        setDataLinkState(.disconnected)
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: (any Error)?
    ) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth service add \(error.map { String(describing: $0) } ?? "ready")")
        #endif
        guard error == nil, service.uuid == AnchorBluetoothService.uuid else { return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [AnchorBluetoothService.uuid]])
    }

    public func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: (any Error)?
    ) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth advertising \(error.map { String(describing: $0) } ?? "ready")")
        #endif
        if error != nil { setDataLinkState(.failed) }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth credential read requested")
        #endif
        guard request.characteristic.uuid == AnchorBluetoothService.pairingCredentialUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        let credential = BluetoothPairingCredential(
            deviceID: deviceID,
            secret: pairingToken.current(),
            challenge: pairingChallenge
        )
        guard let data = try? JSONEncoder().encode(credential) else {
            peripheral.respond(to: request, withResult: .unlikelyError)
            return
        }
        guard request.offset <= data.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = data.subdata(in: request.offset ..< data.count)
        peripheral.respond(to: request, withResult: .success)
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == AnchorBluetoothService.eventTransferUUID else { return }
        subscribedCentrals[central.identifier] = central
        assemblers[central.identifier] = AnchorBluetoothTransferAssembler()
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == AnchorBluetoothService.eventTransferUUID else { return }
        subscribedCentrals[central.identifier] = nil
        peerIDs[central.identifier] = nil
        assemblers[central.identifier] = nil
        outboundTransfers.removeAll { $0.central.identifier == central.identifier }
        if peerIDs.isEmpty { setDataLinkState(.disconnected) }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            guard request.characteristic.uuid == AnchorBluetoothService.eventTransferUUID,
                  request.offset == 0,
                  let value = request.value else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            do {
                var assembler = assemblers[request.central.identifier]
                    ?? AnchorBluetoothTransferAssembler()
                let completed = try assembler.accept(value)
                assemblers[request.central.identifier] = assembler
                peripheral.respond(to: request, withResult: .success)
                if let completed {
                    handleTransfer(completed, from: request.central)
                }
            } catch {
                peripheral.respond(to: request, withResult: .unlikelyError)
            }
        }
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        drainOutboundTransfers()
    }

    private func authenticatedCentral() throws -> (CBCentral, Data) {
        for (centralID, peerID) in peerIDs {
            guard let central = subscribedCentrals[centralID],
                  let key = identityStore.sharedKey(peerID: peerID) else { continue }
            return (central, key)
        }
        throw AnchorLinkError.notPaired
    }

    private func handleTransfer(_ data: Data, from central: CBCentral) {
        guard let frame = try? JSONDecoder.anchor.decode(LinkFrame.self, from: data) else { return }
        if frame.kind == .pairRequest {
            handlePairRequest(frame, from: central)
            return
        }
        guard frame.kind == .encrypted,
              let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID),
              let payload = try? AnchorLinkCodec.open(encrypted, using: key) else { return }
        subscribedCentrals[central.identifier] = central
        peerIDs[central.identifier] = frame.senderID
        setDataLinkState(.connected)

        guard replayWindow.accepts(payload.messageID) else {
            if payload.kind == .event, let event = payload.event {
                try? enqueue(
                    LinkPayload(kind: .acknowledgement, acknowledgedEventID: event.id),
                    key: key,
                    central: central
                )
            }
            return
        }

        switch payload.kind {
        case .heartbeat:
            try? enqueue(LinkPayload(kind: .heartbeat), key: key, central: central)
        case .event:
            guard let event = payload.event, let onEvent else { return }
            let precedingTask = eventApplicationTask
            eventApplicationTask = Task { [weak self] in
                await precedingTask?.value
                guard !Task.isCancelled else { return }
                do {
                    try await onEvent(event)
                } catch {
                    return
                }
                await MainActor.run { [weak self] in
                    guard let self,
                          subscribedCentrals[central.identifier] != nil else { return }
                    try? enqueue(
                        LinkPayload(kind: .acknowledgement, acknowledgedEventID: event.id),
                        key: key,
                        central: central
                    )
                }
            }
        case .acknowledgement:
            if let eventID = payload.acknowledgedEventID {
                finishDelivery(eventID, with: .success(()))
            }
        case .processSnapshotRequest:
            respondToProcessSnapshotRequest(payload.requestID, key: key, central: central)
        case .processSnapshotResponse:
            break
        }
    }

    private func handlePairRequest(_ frame: LinkFrame, from central: CBCentral) {
        guard frame.pairingMethod == .bluetooth,
              frame.challenge == pairingChallenge,
              let clientPublicKey = frame.publicKey,
              let proof = frame.pairingProof else { return }
        let secret = pairingToken.current()
        guard AnchorLinkCodec.validatesPairingProof(
            proof,
            secret: secret,
            method: .bluetooth,
            role: "client",
            clientID: frame.senderID,
            serverID: deviceID,
            clientPublicKey: clientPublicKey,
            challenge: pairingChallenge
        ) else { return }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        do {
            let derived = try AnchorLinkCodec.deriveKey(
                privateKey: privateKey,
                peerPublicKey: clientPublicKey,
                pairingSecret: secret,
                clientID: frame.senderID,
                serverID: deviceID
            )
            try identityStore.saveSharedKey(derived, peerID: frame.senderID)
            peerIDs[central.identifier] = frame.senderID
            let serverPublicKey = privateKey.publicKey.rawRepresentation
            let serverProof = AnchorLinkCodec.pairingProof(
                secret: secret,
                method: .bluetooth,
                role: "server",
                clientID: frame.senderID,
                serverID: deviceID,
                clientPublicKey: clientPublicKey,
                serverPublicKey: serverPublicKey,
                challenge: pairingChallenge
            )
            try enqueueFrame(
                LinkFrame(
                    kind: .pairAccepted,
                    senderID: deviceID,
                    publicKey: serverPublicKey,
                    pairingMethod: .bluetooth,
                    pairingProof: serverProof,
                    challenge: pairingChallenge
                ),
                central: central
            )
            pairingToken.rotate()
            pairingChallenge = Self.makePairingChallenge(secret: pairingToken.current())
        } catch {
            return
        }
    }

    private func respondToProcessSnapshotRequest(
        _ requestID: UUID?,
        key: Data,
        central: CBCentral
    ) {
        guard let requestID else { return }
        let provider = onCurrentProcessSnapshot
        Task { [weak self] in
            let snapshot = try? await provider?()
            await MainActor.run { [weak self] in
                guard let self,
                      subscribedCentrals[central.identifier] != nil else { return }
                try? enqueue(
                    LinkPayload(
                        kind: .processSnapshotResponse,
                        requestID: requestID,
                        currentProcessSnapshot: snapshot
                    ),
                    key: key,
                    central: central
                )
            }
        }
    }

    private func enqueue(_ payload: LinkPayload, key: Data, central: CBCentral) throws {
        guard subscribedCentrals[central.identifier] != nil else {
            throw AnchorLinkError.connectionLost
        }
        let sealed = try AnchorLinkCodec.seal(payload, using: key)
        let frame = LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed)
        try enqueueFrame(frame, central: central)
    }

    private func enqueueFrame(_ frame: LinkFrame, central: CBCentral) throws {
        let data = try JSONEncoder.anchor.encode(frame)
        let chunks = try AnchorBluetoothTransferFramer.chunks(
            for: data,
            maximumValueLength: central.maximumUpdateValueLength
        )
        outboundTransfers.append(OutboundTransfer(central: central, chunks: chunks, nextIndex: 0))
        drainOutboundTransfers()
    }

    private static func makePairingChallenge(secret: Data) -> Data {
        Data(SHA256.hash(data: Data("anchor-ble-challenge-v1".utf8) + secret))
    }

    private func drainOutboundTransfers() {
        guard let manager, let eventCharacteristic else { return }
        while !outboundTransfers.isEmpty {
            var transfer = outboundTransfers[0]
            guard transfer.nextIndex < transfer.chunks.count else {
                outboundTransfers.removeFirst()
                continue
            }
            let accepted = manager.updateValue(
                transfer.chunks[transfer.nextIndex],
                for: eventCharacteristic,
                onSubscribedCentrals: [transfer.central]
            )
            guard accepted else { return }
            transfer.nextIndex += 1
            outboundTransfers[0] = transfer
        }
    }

    private func finishDelivery(_ id: UUID, with result: Result<Void, any Error>) {
        guard let delivery = pendingDeliveries.removeValue(forKey: id) else { return }
        delivery.timeoutWorkItem.cancel()
        delivery.continuation.resume(with: result)
    }

    private func failAllDeliveries(with error: any Error) {
        for id in Array(pendingDeliveries.keys) {
            finishDelivery(id, with: .failure(error))
        }
    }

    private func setDataLinkState(_ state: ConnectionState) {
        guard dataLinkState != state else { return }
        dataLinkState = state
        onConnectionState?(state)
    }
}
#endif

#if os(iOS)
public final class AnchorProximityScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, AnchorEventTransport, CurrentProcessProviding, @unchecked Sendable {
    private typealias OperationContinuation = CheckedContinuation<Void, any Error>
    private typealias SnapshotContinuation = CheckedContinuation<CurrentProcessSnapshot, any Error>

    private struct PendingDelivery {
        let continuation: OperationContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    private struct PendingSnapshotRequest {
        let continuation: SnapshotContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    private struct PairingAttempt {
        let peerID: UUID
        let secret: Data
        let challenge: Data
        let privateKey: Curve25519.KeyAgreement.PrivateKey
    }

    private struct OutboundTransfer {
        let chunks: [Data]
        var nextIndex: Int
    }

    private static let operationTimeout: TimeInterval = 10

    private let onUpdate: @Sendable (ProximityState) -> Void
    private let onPairingCredential: @Sendable (UUID, Data) -> Void
    private let identityStore: PairingIdentityStore
    private let deviceID: UUID
    private var manager: CBCentralManager?
    private var candidatePeripheral: CBPeripheral?
    private var candidateWasNear = false
    private var eventCharacteristic: CBCharacteristic?
    private var peerID: UUID?
    private var staleSignalWorkItem: DispatchWorkItem?
    private var pairingWorkItem: DispatchWorkItem?
    private var pairingAttempt: PairingAttempt?
    private var hasDeliveredPairingCredential = false
    private var assembler = AnchorBluetoothTransferAssembler()
    private var outboundTransfers: [OutboundTransfer] = []
    private var isWriting = false
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var pendingSnapshotRequests: [UUID: PendingSnapshotRequest] = [:]
    private var replayWindow = LinkReplayWindow()
    private var eventApplicationTask: Task<Void, Never>?
    private var dataLinkState = ConnectionState.unavailable
    private var onEvent: (@Sendable (EventEnvelope) async throws -> Void)?
    private var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    public init(
        identityStore: PairingIdentityStore = PairingIdentityStore(),
        onUpdate: @escaping @Sendable (ProximityState) -> Void,
        onPairingCredential: @escaping @Sendable (UUID, Data) -> Void = { _, _ in }
    ) {
        self.identityStore = identityStore
        deviceID = identityStore.localDeviceID()
        self.onUpdate = onUpdate
        self.onPairingCredential = onPairingCredential
    }

    public func setEventHandler(
        _ handler: (@Sendable (EventEnvelope) async throws -> Void)?
    ) {
        DispatchQueue.main.async { [weak self] in self?.onEvent = handler }
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (ConnectionState) -> Void)?
    ) {
        DispatchQueue.main.async { [weak self] in self?.onConnectionState = handler }
    }

    public func start() {
        guard manager == nil else { return }
        manager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey:
                    "com.andywang.anchor.bluetooth-central",
            ]
        )
    }

    public func stop() {
        staleSignalWorkItem?.cancel()
        staleSignalWorkItem = nil
        pairingWorkItem?.cancel()
        pairingWorkItem = nil
        pairingAttempt = nil
        manager?.stopScan()
        if let candidatePeripheral {
            manager?.cancelPeripheralConnection(candidatePeripheral)
        }
        candidatePeripheral = nil
        candidateWasNear = false
        eventCharacteristic = nil
        peerID = nil
        hasDeliveredPairingCredential = false
        outboundTransfers.removeAll()
        isWriting = false
        eventApplicationTask?.cancel()
        eventApplicationTask = nil
        failAllDeliveries(with: CancellationError())
        failAllSnapshotRequests(with: CancellationError())
        setDataLinkState(.unavailable)
        manager = nil
    }

    public func refreshDataLink() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let peerID,
                  let key = identityStore.sharedKey(peerID: peerID) else { return }
            pairingWorkItem?.cancel()
            pairingWorkItem = nil
            pairingAttempt = nil
            try? enqueue(LinkPayload(kind: .heartbeat), key: key)
        }
    }

    public func send(_ event: EventEnvelope) async throws {
        try await withCheckedThrowingContinuation { (continuation: OperationContinuation) in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard pendingDeliveries[event.id] == nil else {
                    continuation.resume(throwing: AnchorLinkError.operationInProgress)
                    return
                }
                do {
                    let key = try authenticatedKey()
                    let timeout = DispatchWorkItem { [weak self] in
                        self?.finishDelivery(
                            event.id,
                            with: .failure(AnchorLinkError.acknowledgementTimedOut)
                        )
                    }
                    pendingDeliveries[event.id] = PendingDelivery(
                        continuation: continuation,
                        timeoutWorkItem: timeout
                    )
                    try enqueue(LinkPayload(kind: .event, event: event), key: key)
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Self.operationTimeout,
                        execute: timeout
                    )
                } catch {
                    pendingDeliveries[event.id] = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func currentProcessSnapshot() async throws -> CurrentProcessSnapshot {
        try await withCheckedThrowingContinuation { (continuation: SnapshotContinuation) in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                let requestID = UUID()
                do {
                    let key = try authenticatedKey()
                    let timeout = DispatchWorkItem { [weak self] in
                        self?.finishSnapshot(
                            requestID,
                            with: .failure(AnchorLinkError.processSnapshotTimedOut)
                        )
                    }
                    pendingSnapshotRequests[requestID] = PendingSnapshotRequest(
                        continuation: continuation,
                        timeoutWorkItem: timeout
                    )
                    try enqueue(
                        LinkPayload(kind: .processSnapshotRequest, requestID: requestID),
                        key: key
                    )
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Self.operationTimeout,
                        execute: timeout
                    )
                } catch {
                    pendingSnapshotRequests[requestID] = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth state \(central.state.rawValue)")
        #endif
        staleSignalWorkItem?.cancel()
        staleSignalWorkItem = nil
        switch central.state {
        case .poweredOn:
            startScanning(central)
            setDataLinkState(.disconnected)
        case .unauthorized:
            onUpdate(.permissionDenied)
            setDataLinkState(.permissionDenied)
        case .unsupported:
            onUpdate(.unavailable)
            setDataLinkState(.unavailable)
        default:
            onUpdate(.unknown)
            setDataLinkState(.unavailable)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        guard let peripheral = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else {
            return
        }
        candidatePeripheral = peripheral
        peripheral.delegate = self
        if peripheral.state == .connected {
            peripheral.discoverServices([AnchorBluetoothService.uuid])
        } else {
            central.connect(peripheral)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let value = RSSI.intValue
        guard value != 127 else {
            onUpdate(.unknown)
            return
        }
        let isNear = value >= -68
        #if DEBUG
        print("[AnchorPairing] Bluetooth candidate RSSI \(value) near=\(isNear)")
        #endif
        onUpdate(isNear ? .near : .far)
        if candidatePeripheral == nil {
            #if DEBUG
            print("[AnchorPairing] Bluetooth connecting candidate")
            #endif
            candidatePeripheral = peripheral
            candidateWasNear = isNear
            peripheral.delegate = self
            central.connect(peripheral)
        }
        scheduleStaleSignalFallback()
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth connected to peripheral")
        #endif
        central.stopScan()
        peripheral.discoverServices([AnchorBluetoothService.uuid])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth connect failed \(String(describing: error))")
        #endif
        if candidatePeripheral === peripheral { candidatePeripheral = nil }
        candidateWasNear = false
        setDataLinkState(.disconnected)
        startScanning(central)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        if candidatePeripheral === peripheral { candidatePeripheral = nil }
        candidateWasNear = false
        eventCharacteristic = nil
        peerID = nil
        hasDeliveredPairingCredential = false
        pairingWorkItem?.cancel()
        pairingWorkItem = nil
        pairingAttempt = nil
        assembler = AnchorBluetoothTransferAssembler()
        outboundTransfers.removeAll()
        isWriting = false
        failAllDeliveries(with: AnchorLinkError.connectionLost)
        failAllSnapshotRequests(with: AnchorLinkError.connectionLost)
        setDataLinkState(.disconnected)
        startScanning(central)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth services result \(String(describing: error))")
        #endif
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == AnchorBluetoothService.uuid }) else {
            disconnect(peripheral)
            return
        }
        peripheral.discoverCharacteristics(
            [
                AnchorBluetoothService.pairingCredentialUUID,
                AnchorBluetoothService.eventTransferUUID,
            ],
            for: service
        )
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        #if DEBUG
        print("[AnchorPairing] Bluetooth characteristics result \(String(describing: error))")
        #endif
        guard error == nil,
              let pairingCharacteristic = service.characteristics?.first(where: {
                  $0.uuid == AnchorBluetoothService.pairingCredentialUUID
              }),
              let eventCharacteristic = service.characteristics?.first(where: {
                  $0.uuid == AnchorBluetoothService.eventTransferUUID
              }) else {
            disconnect(peripheral)
            return
        }
        self.eventCharacteristic = eventCharacteristic
        peripheral.setNotifyValue(true, for: eventCharacteristic)
        peripheral.readValue(for: pairingCharacteristic)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard characteristic.uuid == AnchorBluetoothService.eventTransferUUID else { return }
        if error != nil || !characteristic.isNotifying {
            setDataLinkState(.disconnected)
            return
        }
        refreshDataLink()
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, let value = characteristic.value else { return }
        switch characteristic.uuid {
        case AnchorBluetoothService.pairingCredentialUUID:
            #if DEBUG
            print("[AnchorPairing] Bluetooth credential ready")
            #endif
            guard let credential = try? JSONDecoder().decode(
                BluetoothPairingCredential.self,
                from: value
            ), credential.secret.count == 32 else { return }
            peerID = credential.deviceID
            if candidateWasNear, !hasDeliveredPairingCredential {
                hasDeliveredPairingCredential = true
                onPairingCredential(credential.deviceID, credential.secret)
            }
            if candidateWasNear, let challenge = credential.challenge {
                scheduleDirectPairing(
                    peerID: credential.deviceID,
                    secret: credential.secret,
                    challenge: challenge
                )
            }
            refreshDataLink()
        case AnchorBluetoothService.eventTransferUUID:
            do {
                if let completed = try assembler.accept(value) {
                    handleTransfer(completed)
                }
            } catch {
                assembler = AnchorBluetoothTransferAssembler()
            }
        default:
            break
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard characteristic.uuid == AnchorBluetoothService.eventTransferUUID else { return }
        isWriting = false
        if let error {
            outboundTransfers.removeAll()
            failAllDeliveries(with: error)
            failAllSnapshotRequests(with: error)
            setDataLinkState(.disconnected)
            return
        }
        if !outboundTransfers.isEmpty {
            outboundTransfers[0].nextIndex += 1
            if outboundTransfers[0].nextIndex >= outboundTransfers[0].chunks.count {
                outboundTransfers.removeFirst()
            }
        }
        drainOutboundTransfers()
    }

    private func startScanning(_ central: CBCentralManager) {
        central.scanForPeripherals(
            withServices: [AnchorBluetoothService.uuid],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func authenticatedKey() throws -> Data {
        guard candidatePeripheral != nil,
              eventCharacteristic != nil,
              let peerID,
              let key = identityStore.sharedKey(peerID: peerID) else {
            throw AnchorLinkError.notPaired
        }
        return key
    }

    private func handleTransfer(_ data: Data) {
        guard let frame = try? JSONDecoder.anchor.decode(LinkFrame.self, from: data) else { return }
        if frame.kind == .pairAccepted {
            handlePairAccepted(frame)
            return
        }
        guard frame.kind == .encrypted,
              let expectedPeerID = peerID,
              frame.senderID == expectedPeerID,
              let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID),
              let payload = try? AnchorLinkCodec.open(encrypted, using: key) else { return }
        setDataLinkState(.connected)

        guard replayWindow.accepts(payload.messageID) else {
            if payload.kind == .event, let event = payload.event {
                try? enqueue(
                    LinkPayload(kind: .acknowledgement, acknowledgedEventID: event.id),
                    key: key
                )
            }
            return
        }

        switch payload.kind {
        case .heartbeat:
            break
        case .event:
            guard let event = payload.event, let onEvent else { return }
            let precedingTask = eventApplicationTask
            eventApplicationTask = Task { [weak self] in
                await precedingTask?.value
                guard !Task.isCancelled else { return }
                do {
                    try await onEvent(event)
                } catch {
                    return
                }
                await MainActor.run { [weak self] in
                    try? self?.enqueue(
                        LinkPayload(kind: .acknowledgement, acknowledgedEventID: event.id),
                        key: key
                    )
                }
            }
        case .acknowledgement:
            if let eventID = payload.acknowledgedEventID {
                finishDelivery(eventID, with: .success(()))
            }
        case .processSnapshotResponse:
            guard let requestID = payload.requestID else { return }
            if let snapshot = payload.currentProcessSnapshot {
                finishSnapshot(requestID, with: .success(snapshot))
            } else {
                finishSnapshot(requestID, with: .failure(AnchorLinkError.processSnapshotUnavailable))
            }
        case .processSnapshotRequest:
            break
        }
    }

    private func scheduleDirectPairing(peerID: UUID, secret: Data, challenge: Data) {
        pairingWorkItem?.cancel()
        guard identityStore.sharedKey(peerID: peerID) == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  identityStore.sharedKey(peerID: peerID) == nil else { return }
            pairingWorkItem = nil
            let attempt = PairingAttempt(
                peerID: peerID,
                secret: secret,
                challenge: challenge,
                privateKey: Curve25519.KeyAgreement.PrivateKey()
            )
            pairingAttempt = attempt
            let clientPublicKey = attempt.privateKey.publicKey.rawRepresentation
            let proof = AnchorLinkCodec.pairingProof(
                secret: secret,
                method: .bluetooth,
                role: "client",
                clientID: deviceID,
                serverID: peerID,
                clientPublicKey: clientPublicKey,
                challenge: challenge
            )
            try? enqueueFrame(
                LinkFrame(
                    kind: .pairRequest,
                    senderID: deviceID,
                    publicKey: clientPublicKey,
                    pairingMethod: .bluetooth,
                    pairingProof: proof,
                    challenge: challenge
                )
            )
        }
        pairingWorkItem = workItem
        // Give infrastructure and peer-to-peer Wi-Fi the first opportunity.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func handlePairAccepted(_ frame: LinkFrame) {
        guard let attempt = pairingAttempt,
              frame.senderID == attempt.peerID,
              frame.pairingMethod == .bluetooth,
              frame.challenge == attempt.challenge,
              let serverPublicKey = frame.publicKey,
              let proof = frame.pairingProof,
              AnchorLinkCodec.validatesPairingProof(
                  proof,
                  secret: attempt.secret,
                  method: .bluetooth,
                  role: "server",
                  clientID: deviceID,
                  serverID: frame.senderID,
                  clientPublicKey: attempt.privateKey.publicKey.rawRepresentation,
                  serverPublicKey: serverPublicKey,
                  challenge: attempt.challenge
              ) else { return }
        do {
            let key = try AnchorLinkCodec.deriveKey(
                privateKey: attempt.privateKey,
                peerPublicKey: serverPublicKey,
                pairingSecret: attempt.secret,
                clientID: deviceID,
                serverID: frame.senderID
            )
            try identityStore.saveSharedKey(key, peerID: frame.senderID)
            pairingAttempt = nil
            try enqueue(LinkPayload(kind: .heartbeat), key: key)
        } catch {
            pairingAttempt = nil
        }
    }

    private func enqueue(_ payload: LinkPayload, key: Data) throws {
        let sealed = try AnchorLinkCodec.seal(payload, using: key)
        let frame = LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed)
        try enqueueFrame(frame)
    }

    private func enqueueFrame(_ frame: LinkFrame) throws {
        guard let peripheral = candidatePeripheral,
              let eventCharacteristic,
              eventCharacteristic.isNotifying else {
            throw AnchorLinkError.connectionLost
        }
        let data = try JSONEncoder.anchor.encode(frame)
        let chunks = try AnchorBluetoothTransferFramer.chunks(
            for: data,
            maximumValueLength: peripheral.maximumWriteValueLength(for: .withResponse)
        )
        outboundTransfers.append(OutboundTransfer(chunks: chunks, nextIndex: 0))
        drainOutboundTransfers()
    }

    private func drainOutboundTransfers() {
        guard !isWriting,
              !outboundTransfers.isEmpty,
              let peripheral = candidatePeripheral,
              let eventCharacteristic else { return }
        let transfer = outboundTransfers[0]
        guard transfer.nextIndex < transfer.chunks.count else {
            outboundTransfers.removeFirst()
            drainOutboundTransfers()
            return
        }
        isWriting = true
        peripheral.writeValue(
            transfer.chunks[transfer.nextIndex],
            for: eventCharacteristic,
            type: .withResponse
        )
    }

    private func finishDelivery(_ id: UUID, with result: Result<Void, any Error>) {
        guard let delivery = pendingDeliveries.removeValue(forKey: id) else { return }
        delivery.timeoutWorkItem.cancel()
        delivery.continuation.resume(with: result)
    }

    private func failAllDeliveries(with error: any Error) {
        for id in Array(pendingDeliveries.keys) {
            finishDelivery(id, with: .failure(error))
        }
    }

    private func finishSnapshot(
        _ requestID: UUID,
        with result: Result<CurrentProcessSnapshot, any Error>
    ) {
        guard let request = pendingSnapshotRequests.removeValue(forKey: requestID) else { return }
        request.timeoutWorkItem.cancel()
        request.continuation.resume(with: result)
    }

    private func failAllSnapshotRequests(with error: any Error) {
        for requestID in Array(pendingSnapshotRequests.keys) {
            finishSnapshot(requestID, with: .failure(error))
        }
    }

    private func setDataLinkState(_ state: ConnectionState) {
        guard dataLinkState != state else { return }
        dataLinkState = state
        onConnectionState?(state)
    }

    private func disconnect(_ peripheral: CBPeripheral) {
        manager?.cancelPeripheralConnection(peripheral)
        if candidatePeripheral === peripheral {
            candidatePeripheral = nil
            candidateWasNear = false
        }
    }

    private func scheduleStaleSignalFallback() {
        staleSignalWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onUpdate(.unknown)
        }
        staleSignalWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: workItem)
    }
}
#endif
