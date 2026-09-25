import AnchorCore
import Foundation

/// Keeps the existing network path as the fast path and falls back to the
/// nearby Bluetooth event channel only when the network transport cannot send.
public struct AnchorAdaptiveEventTransport: AnchorEventTransport, Sendable {
    private let network: any AnchorEventTransport
    private let bluetooth: any AnchorEventTransport

    public init(
        network: any AnchorEventTransport,
        bluetooth: any AnchorEventTransport
    ) {
        self.network = network
        self.bluetooth = bluetooth
    }

    public func send(_ event: EventEnvelope) async throws {
        do {
            try await network.send(event)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try await bluetooth.send(event)
        }
    }
}

/// Process snapshots are small enough for Bluetooth and use the same fallback
/// order as task events. Large resources remain on the network path.
public struct AnchorAdaptiveCurrentProcessProvider: CurrentProcessProviding, Sendable {
    private let network: any CurrentProcessProviding
    private let bluetooth: any CurrentProcessProviding

    public init(
        network: any CurrentProcessProviding,
        bluetooth: any CurrentProcessProviding
    ) {
        self.network = network
        self.bluetooth = bluetooth
    }

    public func currentProcessSnapshot() async throws -> CurrentProcessSnapshot {
        do {
            return try await network.currentProcessSnapshot()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await bluetooth.currentProcessSnapshot()
        }
    }
}

enum AnchorBluetoothTransferError: Error, Equatable {
    case invalidChunk
    case payloadTooLarge
}

struct AnchorBluetoothTransferChunk: Equatable, Sendable {
    static let headerSize = 21
    static let maximumPayloadSize = 256 * 1_024
    static let maximumChunkCount = 4_096

    let transferID: UUID
    let index: Int
    let count: Int
    let payload: Data

    init(transferID: UUID, index: Int, count: Int, payload: Data) {
        self.transferID = transferID
        self.index = index
        self.count = count
        self.payload = payload
    }

    func encoded() throws -> Data {
        guard count > 0,
              count <= Self.maximumChunkCount,
              index >= 0,
              index < count,
              index <= Int(UInt16.max),
              count <= Int(UInt16.max) else {
            throw AnchorBluetoothTransferError.invalidChunk
        }

        var data = Data([1])
        var uuid = transferID.uuid
        withUnsafeBytes(of: &uuid) { data.append(contentsOf: $0) }
        data.append(UInt8(index >> 8))
        data.append(UInt8(index & 0xFF))
        data.append(UInt8(count >> 8))
        data.append(UInt8(count & 0xFF))
        data.append(payload)
        return data
    }

    init(encoded data: Data) throws {
        guard data.count >= Self.headerSize, data[0] == 1 else {
            throw AnchorBluetoothTransferError.invalidChunk
        }
        var uuidBytes: uuid_t = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
        _ = withUnsafeMutableBytes(of: &uuidBytes) { destination in
            data.copyBytes(to: destination, from: 1 ..< 17)
        }
        transferID = UUID(uuid: uuidBytes)
        index = Int(data[17]) << 8 | Int(data[18])
        count = Int(data[19]) << 8 | Int(data[20])
        payload = data.subdata(in: Self.headerSize ..< data.count)
        guard count > 0,
              count <= Self.maximumChunkCount,
              index < count else {
            throw AnchorBluetoothTransferError.invalidChunk
        }
    }
}

enum AnchorBluetoothTransferFramer {
    static func chunks(for payload: Data, maximumValueLength: Int) throws -> [Data] {
        guard payload.count <= AnchorBluetoothTransferChunk.maximumPayloadSize else {
            throw AnchorBluetoothTransferError.payloadTooLarge
        }
        let payloadCapacity = maximumValueLength - AnchorBluetoothTransferChunk.headerSize
        guard payloadCapacity > 0 else { throw AnchorBluetoothTransferError.invalidChunk }
        let chunkCount = max(1, Int(ceil(Double(payload.count) / Double(payloadCapacity))))
        guard chunkCount <= AnchorBluetoothTransferChunk.maximumChunkCount else {
            throw AnchorBluetoothTransferError.payloadTooLarge
        }
        let transferID = UUID()
        return try (0 ..< chunkCount).map { index in
            let start = min(index * payloadCapacity, payload.count)
            let end = min(start + payloadCapacity, payload.count)
            return try AnchorBluetoothTransferChunk(
                transferID: transferID,
                index: index,
                count: chunkCount,
                payload: payload.subdata(in: start ..< end)
            ).encoded()
        }
    }
}

struct AnchorBluetoothTransferAssembler: Sendable {
    private struct Transfer: Sendable {
        let count: Int
        var chunks: [Int: Data]
        var byteCount: Int
    }

    private static let maximumActiveTransfers = 8
    private var transfers: [UUID: Transfer] = [:]
    private var insertionOrder: [UUID] = []

    mutating func accept(_ data: Data) throws -> Data? {
        let chunk = try AnchorBluetoothTransferChunk(encoded: data)
        if transfers[chunk.transferID] == nil {
            while insertionOrder.count >= Self.maximumActiveTransfers,
                  let expiredID = insertionOrder.first {
                insertionOrder.removeFirst()
                transfers[expiredID] = nil
            }
            transfers[chunk.transferID] = Transfer(count: chunk.count, chunks: [:], byteCount: 0)
            insertionOrder.append(chunk.transferID)
        }
        guard var transfer = transfers[chunk.transferID], transfer.count == chunk.count else {
            throw AnchorBluetoothTransferError.invalidChunk
        }
        if let existing = transfer.chunks[chunk.index] {
            guard existing == chunk.payload else {
                transfers[chunk.transferID] = nil
                insertionOrder.removeAll { $0 == chunk.transferID }
                throw AnchorBluetoothTransferError.invalidChunk
            }
        } else {
            transfer.chunks[chunk.index] = chunk.payload
            transfer.byteCount += chunk.payload.count
        }
        guard transfer.byteCount <= AnchorBluetoothTransferChunk.maximumPayloadSize else {
            transfers[chunk.transferID] = nil
            insertionOrder.removeAll { $0 == chunk.transferID }
            throw AnchorBluetoothTransferError.payloadTooLarge
        }
        transfers[chunk.transferID] = transfer
        guard transfer.chunks.count == transfer.count else { return nil }

        var payload = Data()
        payload.reserveCapacity(transfer.byteCount)
        for index in 0 ..< transfer.count {
            guard let part = transfer.chunks[index] else {
                throw AnchorBluetoothTransferError.invalidChunk
            }
            payload.append(part)
        }
        transfers[chunk.transferID] = nil
        insertionOrder.removeAll { $0 == chunk.transferID }
        return payload
    }
}
