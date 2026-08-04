import Foundation
import Network

final class LineConnection: @unchecked Sendable {
    let connection: NWConnection
    private let queue: DispatchQueue
    private var buffer = Data()
    private var onFrame: (@Sendable (LinkFrame) -> Void)?
    private var onState: (@Sendable (NWConnection.State) -> Void)?

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    func start(
        onFrame: @escaping @Sendable (LinkFrame) -> Void,
        onState: @escaping @Sendable (NWConnection.State) -> Void
    ) {
        self.onFrame = onFrame
        self.onState = onState
        connection.stateUpdateHandler = { [weak self] state in
            self?.onState?(state)
            if case .ready = state { self?.receive() }
        }
        connection.start(queue: queue)
    }

    func send(_ frame: LinkFrame) {
        guard let encoded = try? JSONEncoder.anchor.encode(frame) else { return }
        var line = encoded
        line.append(0x0A)
        connection.send(content: line, completion: .contentProcessed { _ in })
    }

    func cancel() {
        connection.cancel()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { self.consume(data) }
            if error == nil, !isComplete {
                self.receive()
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let frameData = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if let frame = try? JSONDecoder.anchor.decode(LinkFrame.self, from: frameData), frame.version == 1 {
                onFrame?(frame)
            }
        }
    }
}
