#if os(macOS)
import AppKit
import CoreGraphics
import Foundation

/// When the person was away from this Mac (B7): ten minutes without keyboard
/// or mouse, or a lock or sleep. Each return is reported once, with the moment
/// they left; a short lock is not worth a welcome back.
struct MacAwayTracker {
    static let idleThreshold: TimeInterval = 10 * 60
    static let shortestAway: TimeInterval = 3 * 60
    /// Input this recent means the person is at the keyboard again.
    static let backThreshold: TimeInterval = 5

    private(set) var awaySince: Date?
    private var screenLocked = false
    private var asleep = false

    var isAway: Bool { awaySince != nil }

    /// System input idle time. Returns the moment the person left when they come back.
    mutating func idle(_ seconds: TimeInterval, now: Date) -> Date? {
        guard !screenLocked, !asleep else { return nil }
        if isAway {
            return seconds < Self.backThreshold ? endAway(now: now) : nil
        }
        if seconds >= Self.idleThreshold { awaySince = now.addingTimeInterval(-seconds) }
        return nil
    }

    mutating func screenDidLock(now: Date) {
        screenLocked = true
        beginAway(now: now)
    }

    mutating func screenDidUnlock(now: Date) -> Date? {
        screenLocked = false
        return asleep ? nil : endAway(now: now)
    }

    mutating func didSleep(now: Date) {
        asleep = true
        beginAway(now: now)
    }

    /// Waking onto a locked screen is not a return yet; unlocking is.
    mutating func didWake(now: Date) -> Date? {
        asleep = false
        return screenLocked ? nil : endAway(now: now)
    }

    private mutating func beginAway(now: Date) {
        if awaySince == nil { awaySince = now }
    }

    private mutating func endAway(now: Date) -> Date? {
        guard let since = awaySince else { return nil }
        awaySince = nil
        return now.timeIntervalSince(since) >= Self.shortestAway ? since : nil
    }
}

/// Watches system idle time, screen lock and sleep, and reports when the
/// person leaves and when they come back. It reads only how long input has
/// been idle, never the input itself, and needs no permission.
@MainActor
public final class MacAwayMonitor {
    private var tracker = MacAwayTracker()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var pollTask: Task<Void, Never>?
    private let onLeave: @MainActor () -> Void
    private let onReturn: @MainActor (Date) -> Void

    public init(onLeave: @escaping @MainActor () -> Void = {}, onReturn: @escaping @MainActor (Date) -> Void) {
        self.onLeave = onLeave
        self.onReturn = onReturn
    }

    public func start() {
        guard pollTask == nil else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observe(workspace, name) { $0.tracker.didSleep(now: .now); return nil }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observe(workspace, name) { $0.tracker.didWake(now: .now) }
        }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.tracker.screenDidLock(now: .now); return nil }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.tracker.screenDidUnlock(now: .now) }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                // Check often only while away, so the return is noticed within seconds.
                let away = self?.poll() ?? false
                try? await Task.sleep(for: .seconds(away ? 2 : 30))
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        for (center, observer) in observers { center.removeObserver(observer) }
        observers = []
    }

    private func poll() -> Bool {
        let wasAway = tracker.isAway
        report(tracker.idle(Self.idleSeconds(), now: .now), wasAway: wasAway)
        return tracker.isAway
    }

    /// Seconds since the last keyboard, mouse or trackpad input from real hardware.
    private static func idleSeconds() -> TimeInterval {
        // kCGAnyInputEventType (~0) has no case of its own in the Swift enum.
        if let anyInput = CGEventType(rawValue: ~0) {
            return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
        }
        return [CGEventType.keyDown, .mouseMoved, .leftMouseDown, .scrollWheel]
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? 0
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ change: @escaping @MainActor (MacAwayMonitor) -> Date?) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let wasAway = self.tracker.isAway
                self.report(change(self), wasAway: wasAway)
            }
        }
        observers.append((center, observer))
    }

    private func report(_ returned: Date?, wasAway: Bool) {
        if !wasAway, tracker.isAway { onLeave() }
        if let returned { onReturn(returned) }
    }
}
#endif
