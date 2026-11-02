import Foundation

/// Tokens agents used per half hour, read from Codex and Claude Code logs and
/// DeepSeek Harness status files.
/// Counts fresh input plus output; cached reads are left out, since they
/// repeat context the agent already paid for. Only counts leave the logs.
public actor TokenTally {
    private struct FileTally {
        let size: UInt64
        let modified: Date
        let slots: [Date: Int]
        /// A harness session's running total when last read.
        var total: Int? = nil
    }

    private var files: [URL: FileTally] = [:]

    public init() {}

    /// Slots since `since`, oldest first, from every log under `roots` changed since then.
    public func slots(under roots: [URL], since: Date) -> [DayActivity.TokenSlot] {
        var seen = Set<URL>()
        for root in roots {
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in walker
            where url.pathExtension == "jsonl" || HarnessSessionStatus.isStatusFile(url) {
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate, modified >= since else { continue }
                let size = UInt64(values.fileSize ?? 0)
                seen.insert(url)
                if let known = files[url], known.size == size, known.modified == modified { continue }
                if url.pathExtension == "json" {
                    if let tally = Self.harness(url, modified: modified, known: files[url], since: since) {
                        files[url] = tally
                    }
                } else {
                    files[url] = FileTally(size: size, modified: modified, slots: Self.read(url))
                }
            }
        }
        files = files.filter { seen.contains($0.key) }
        let floor = DayActivity.slotStart(of: since)
        var totals: [Date: Int] = [:]
        for tally in files.values {
            for (start, tokens) in tally.slots where start >= floor { totals[start, default: 0] += tokens }
        }
        return totals.sorted { $0.key < $1.key }.map { DayActivity.TokenSlot(start: $0.key, tokens: $0.value) }
    }

    /// A harness session keeps only a running total, so its rise since the last
    /// read is put in the half hour the file changed. On first sight, a session
    /// begun today counts whole; an older one counts only what it adds from now.
    private static func harness(_ url: URL, modified: Date, known: FileTally?, since: Date) -> FileTally? {
        guard let status = HarnessSessionStatus(contentsOf: url) else { return nil }
        var slots = known?.slots ?? [:]
        let added: Int
        if let previous = known?.total {
            added = max(0, status.tokens - previous)
        } else {
            added = (status.createdAt ?? .distantPast) >= since ? status.tokens : 0
        }
        if added > 0 { slots[DayActivity.slotStart(of: modified), default: 0] += added }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }.map(UInt64.init) ?? 0
        return FileTally(size: size, modified: modified, slots: slots, total: status.tokens)
    }

    static func read(_ url: URL) -> [Date: Int] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [:] }
        var slots: [Date: Int] = [:]
        var codexTotal = 0
        var claudeMessages = Set<String>()
        for line in data.split(separator: UInt8(ascii: "\n")) {
            let isCodex = line.firstRange(of: Self.codexMarker) != nil
            guard isCodex || line.firstRange(of: Self.claudeMarker) != nil,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let stamp = object["timestamp"] as? String, let at = Self.date(stamp) else { continue }
            var tokens = 0
            if isCodex {
                // Codex reports a running total; its rise is what this moment used.
                guard let info = (object["payload"] as? [String: Any])?["info"] as? [String: Any],
                      let usage = info["total_token_usage"] as? [String: Any] else { continue }
                let total = Self.int(usage["input_tokens"]) - Self.int(usage["cached_input_tokens"])
                    + Self.int(usage["output_tokens"])
                tokens = max(0, total - codexTotal)
                codexTotal = max(codexTotal, total)
            } else {
                // One reply spans several entries that repeat the same usage.
                guard let message = object["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any],
                      let id = message["id"] as? String, claudeMessages.insert(id).inserted else { continue }
                tokens = Self.int(usage["input_tokens"]) + Self.int(usage["cache_creation_input_tokens"])
                    + Self.int(usage["output_tokens"])
            }
            if tokens > 0 { slots[DayActivity.slotStart(of: at), default: 0] += tokens }
        }
        return slots
    }

    private static let codexMarker = Data(#""type":"token_count""#.utf8)
    private static let claudeMarker = Data(#""usage""#.utf8)

    private static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }

    private static func date(_ text: String) -> Date? {
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return (try? fractional.parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text))
    }
}

/// The Mac's side of the day: records the phone's Bluetooth link and sends
/// the day so far to the phone every few minutes and whenever the link comes up.
public actor DayActivityReporter {
    private let sourceID: UUID
    private let roots: @Sendable () async -> [URL]
    private let send: @Sendable (EventEnvelope) async throws -> Void
    private let tally = TokenTally()
    private var linkedSince: Date?
    private var loop: Task<Void, Never>?
    private var defaults: UserDefaults { .standard }
    private static let linksKey = "anchor.activity.links"
    /// Long enough to cover a 12-hour window that started yesterday.
    private static let kept: TimeInterval = 36 * 3600

    public init(sourceID: UUID,
                roots: @escaping @Sendable () async -> [URL],
                send: @escaping @Sendable (EventEnvelope) async throws -> Void) {
        self.sourceID = sourceID
        self.roots = roots
        self.send = send
    }

    public func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.report()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    public func linkChanged(connected: Bool, at now: Date = .now) async {
        if connected {
            guard linkedSince == nil else { return }
            linkedSince = now
            // The encrypted channel may still be settling; try again shortly.
            for delay in [0, 3, 10, 30] {
                try? await Task.sleep(for: .seconds(delay))
                guard linkedSince != nil else { return }
                if await report() { return }
            }
        } else if let start = linkedSince {
            linkedSince = nil
            var links = storedLinks().filter { $0.end > now.addingTimeInterval(-Self.kept) }
            if now > start { links.append(DateInterval(start: start, end: now)) }
            if let data = try? JSONEncoder().encode(links) { defaults.set(data, forKey: Self.linksKey) }
        }
    }

    /// Whether the phone took it.
    @discardableResult
    public func report() async -> Bool {
        let now = Date.now
        let slots = await tally.slots(under: roots(), since: now.addingTimeInterval(-24 * 3600))
        var links = storedLinks()
        if let linkedSince, now > linkedSince { links.append(DateInterval(start: linkedSince, end: now)) }
        guard let envelope = try? DayActivity(tokens: slots, links: links, writtenAt: now).envelope(sourceID: sourceID)
        else { return false }
        // A snapshot: if it doesn't arrive, the next one says the same and more.
        do {
            try await send(envelope)
            return true
        } catch {
            return false
        }
    }

    private func storedLinks() -> [DateInterval] {
        defaults.data(forKey: Self.linksKey).flatMap { try? JSONDecoder().decode([DateInterval].self, from: $0) } ?? []
    }
}
