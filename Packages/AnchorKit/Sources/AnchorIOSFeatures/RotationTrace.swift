#if os(iOS)
import Foundation
import os

/// Debug-build notes around turning the phone, for finding what holds the
/// screen when it turns. Each note carries the time since the first note and
/// the thread it came from; a watcher reports any time the main thread was
/// blocked, with the last note before it. Read them in Xcode's console or in
/// Console.app (subsystem `com.andywang.anchor`, category `rotation`).
/// Release builds note nothing.
enum RotationTrace {
    private static let log = Logger(subsystem: "com.andywang.anchor", category: "rotation")
    private static let state = OSAllocatedUnfairLock(initialState: (origin: Date?.none, last: "launch"))

    /// One step, optionally with how long it took.
    static func note(_ step: String, took seconds: TimeInterval? = nil, remembered: Bool = true) {
        #if DEBUG
        let now = Date.now
        let origin = state.withLock { state in
            if remembered { state.last = step }
            if state.origin == nil { state.origin = now }
            return state.origin ?? now
        }
        let at = String(format: "+%.3fs", now.timeIntervalSince(origin))
        let thread = Thread.isMainThread ? "main" : "bg"
        if let seconds {
            let ms = Int((seconds * 1000).rounded())
            if ms >= 50 {
                log.error("\(at, privacy: .public) \(thread, privacy: .public) | \(step, privacy: .public) took \(ms) ms")
            } else {
                log.notice("\(at, privacy: .public) \(thread, privacy: .public) | \(step, privacy: .public) took \(ms) ms")
            }
        } else {
            log.notice("\(at, privacy: .public) \(thread, privacy: .public) | \(step, privacy: .public)")
        }
        #endif
    }

    /// Runs `work` and notes how long it took when that was more than a frame.
    @discardableResult
    static func measure<T>(_ step: String, _ work: () throws -> T) rethrows -> T {
        #if DEBUG
        let began = Date.now
        defer {
            let took = Date.now.timeIntervalSince(began)
            if took > 0.008 { note(step, took: took) }
        }
        #endif
        return try work()
    }

    static var lastStep: String { state.withLock { $0.last } }

    /// Starts the main-thread watcher once; later calls do nothing.
    static func watchMainThread() {
        #if DEBUG
        MainThreadWatch.shared.start()
        #endif
    }
}

/// Asks the main thread to answer every 50 ms from a queue of its own. An
/// answer that comes back late means the main thread was blocked that long,
/// and the screen with it.
private final class MainThreadWatch: @unchecked Sendable {
    static let shared = MainThreadWatch()

    /// Longer than this is worth a line: about six frames.
    private static let threshold: TimeInterval = 0.1
    private let queue = DispatchQueue(label: "anchor.rotation.watch", qos: .userInteractive)
    private let started = OSAllocatedUnfairLock(initialState: false)

    func start() {
        let first = started.withLock { started in
            defer { started = true }
            return !started
        }
        guard first else { return }
        RotationTrace.note("main-thread watch on")
        queue.async { self.ping() }
    }

    private func ping() {
        let sent = Date.now
        let before = RotationTrace.lastStep
        DispatchQueue.main.async {
            let late = Date.now.timeIntervalSince(sent)
            if late > Self.threshold {
                RotationTrace.note("MAIN THREAD BLOCKED (after: \(before))", took: late, remembered: false)
            }
            self.queue.asyncAfter(deadline: .now() + 0.05) { self.ping() }
        }
    }
}
#endif
