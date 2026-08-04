import AnchorCore
@preconcurrency import CoreBluetooth
import Foundation

public enum AnchorBluetoothService {
    public static var uuid: CBUUID { CBUUID(string: "A11C0001-4E43-484F-5220-414E43484F52") }
}

#if os(macOS)
public final class AnchorProximityAdvertiser: NSObject, CBPeripheralManagerDelegate, @unchecked Sendable {
    private var manager: CBPeripheralManager?

    public func start() {
        guard manager == nil else { return }
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    public func stop() {
        manager?.stopAdvertising()
        manager = nil
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            peripheral.stopAdvertising()
            return
        }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [AnchorBluetoothService.uuid]])
    }
}
#endif

#if os(iOS)
public final class AnchorProximityScanner: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private let onUpdate: @Sendable (ProximityState) -> Void
    private var manager: CBCentralManager?
    private var staleSignalWorkItem: DispatchWorkItem?

    public init(onUpdate: @escaping @Sendable (ProximityState) -> Void) {
        self.onUpdate = onUpdate
    }

    public func start() {
        guard manager == nil else { return }
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    public func stop() {
        staleSignalWorkItem?.cancel()
        staleSignalWorkItem = nil
        manager?.stopScan()
        manager = nil
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        staleSignalWorkItem?.cancel()
        staleSignalWorkItem = nil
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(
                withServices: [AnchorBluetoothService.uuid],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        case .unauthorized:
            onUpdate(.permissionDenied)
        case .unsupported:
            onUpdate(.unavailable)
        default:
            onUpdate(.unknown)
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
        onUpdate(value >= -68 ? .near : .far)
        scheduleStaleSignalFallback()
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
