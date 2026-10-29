#if os(iOS)
import AnchorDesign
import AVFAudio
import Observation
import OSLog
import Speech

@MainActor
@Observable
final class SpeechInputController {
    private enum RecordingSetupError: Error {
        case invalidInputFormat
    }

    private nonisolated static let logger = Logger(
        subsystem: "com.andywang.anchor",
        category: "Speech"
    )
    private nonisolated static let audioSessionQueue = DispatchQueue(
        label: "com.andywang.anchor.speech.audio-session"
    )

    // Accessed only on audioSessionQueue. An older activation may finish after
    // the user has cancelled and started a new recording.
    private nonisolated(unsafe) static var activeAudioSessionID: UUID?

    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var isRequestingPermission = false
    private var recognitionID = UUID()
    private(set) var audioLevel = 0.0
    private var lastMeterUpdate = Date.distantPast
    private var pendingMeterLevel = 0.0
    private(set) var errorMessage: String?

    /// Words the tour is saying; `finish()` completes them at once.
    @ObservationIgnored private var scripted: String?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var baseText = ""

    func start(initialText: String) {
        guard !isRecording, !isRequestingPermission else { return }
        recognitionID = UUID()
        let requestID = recognitionID
        isRequestingPermission = true
        errorMessage = nil
        baseText = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = baseText
        audioLevel = 0
        lastMeterUpdate = .distantPast
        pendingMeterLevel = 0

        Task { @MainActor [weak self] in
            // Speech invokes its legacy callback on a private queue.
            let speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { @Sendable status in
                    continuation.resume(returning: status)
                }
            }
            guard let self, self.recognitionID == requestID else { return }
            guard speechStatus == .authorized else {
                self.isRequestingPermission = false
                self.errorMessage = Self.authorizationMessage(for: speechStatus)
                return
            }

            // Finish both permission prompts before touching AVAudioEngine.
            let microphoneGranted = await AVAudioApplication.requestRecordPermission()
            guard self.recognitionID == requestID else { return }
            guard microphoneGranted else {
                self.isRequestingPermission = false
                self.errorMessage = L10n.voiceInputMicrophoneDenied
                return
            }

            await self.beginRecognition(requestID: requestID)
            if self.recognitionID == requestID { self.isRequestingPermission = false }
        }
    }

    /// The tour's dictation: the words arrive whole, as a recognizer hears
    /// them, at an ordinary speaking pace (about 160 words a minute; Chinese
    /// two or three characters at a time), with a level that moves like a
    /// voice. No microphone, recognizer or permission is touched. Returns
    /// false when something stopped it part way.
    func play(_ text: String) async -> Bool {
        stop()
        let id = UUID()
        recognitionID = id
        errorMessage = nil
        transcript = ""
        scripted = text
        isRecording = true
        speaking: for chunk in Self.spokenChunks(of: text) {
            let ideographs = chunk.filter(\.isIdeograph).count
            var left = ideographs > 0 ? ideographs * 210 : Int.random(in: 330...410)
            transcript += chunk
            while left > 0 {
                guard recognitionID == id, scripted != nil, !Task.isCancelled else { break speaking }
                audioLevel = .random(in: 0.35...0.95)
                try? await Task.sleep(for: .milliseconds(min(left, 95)))
                left -= 95
            }
            // A breath at a comma or a full stop.
            if chunk.contains(where: \.isPunctuation) {
                audioLevel = 0.1
                try? await Task.sleep(for: .milliseconds(260))
            }
        }
        guard recognitionID == id else { return false }
        scripted = nil
        transcript = text
        isRecording = false
        audioLevel = 0
        return !Task.isCancelled
    }

    /// The pieces dictation adds at a time: a word with the space and
    /// punctuation after it, or two or three Chinese characters.
    static func spokenChunks(of text: String) -> [String] {
        var chunks: [String] = []
        var chunk = ""
        var ideographs = 0
        for (index, character) in text.enumerated() {
            chunk.append(character)
            if character.isIdeograph { ideographs += 1 }
            let next = text.dropFirst(index + 1).first
            let ends = character.isWhitespace
                || (character.isPunctuation && next?.isWhitespace != true)
                || (ideographs >= 2 + chunks.count % 2 && next?.isPunctuation != true)
            if ends {
                chunks.append(chunk)
                chunk = ""
                ideographs = 0
            }
        }
        if !chunk.isEmpty { chunks.append(chunk) }
        return chunks
    }

    func stop() {
        // Invalidate permission and recognition callbacks before changing segments.
        let stoppedID = recognitionID
        recognitionID = UUID()
        isRequestingPermission = false
        guard isRecording || audioEngine != nil else { return }
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        Self.deactivateRecordingSession(requestID: stoppedID)
        isRecording = false
        audioLevel = 0
        pendingMeterLevel = 0
    }

    /// Ends a hold: the microphone closes at once, and the recognizer gets a
    /// moment to deliver the last words before everything stops.
    func finish() {
        if scripted != nil {
            scripted = nil
            return
        }
        guard isRecording, let audioEngine else {
            stop()
            return
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        audioLevel = 0
        pendingMeterLevel = 0
        // The final result calls stop(); this covers a recognizer that never sends one.
        let finishingID = recognitionID
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, self.recognitionID == finishingID else { return }
            self.stop()
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func beginRecognition(requestID: UUID) async {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            errorMessage = L10n.voiceInputUnavailable
            return
        }

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        let requestSink = SpeechAudioRequestSink(request)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        do {
            try await Self.activateRecordingSession(requestID: requestID)
            guard recognitionID == requestID else {
                Self.deactivateRecordingSession(requestID: requestID)
                return
            }

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw RecordingSetupError.invalidInputFormat
            }
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { @Sendable [requestSink, weak self] buffer, _ in
                requestSink.append(buffer)
                guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
                var energy: Float = 0
                for index in 0..<Int(buffer.frameLength) { energy += samples[index] * samples[index] }
                // Map actual microphone RMS to a perceptual range. Linear RMS
                // barely moves for quiet speech or microphones with low gain.
                let rms = Double(sqrt(energy / Float(buffer.frameLength)))
                let decibels = 20 * log10(max(rms, 0.000_001))
                // Give quiet/normal speech more of the visual range while
                // retaining headroom up to -25 dBFS for louder syllables.
                let level = min(1, max(0, (decibels + 65) / 40))
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionID == requestID else { return }
                    // Preserve short syllable peaks between display updates instead
                    // of discarding all buffers that arrive during the throttle.
                    self.pendingMeterLevel = max(self.pendingMeterLevel, level)
                    guard Date.now.timeIntervalSince(self.lastMeterUpdate) >= 0.04 else { return }
                    self.lastMeterUpdate = .now
                    let measuredLevel = self.pendingMeterLevel
                    self.pendingMeterLevel = 0
                    // Follow attacks immediately and let pauses fall visibly, rather
                    // than smoothing adjacent syllables into a nearly constant bar.
                    let response = measuredLevel > self.audioLevel ? 0.95 : 0.65
                    self.audioLevel += (measuredLevel - self.audioLevel) * response
                }
            }

            recognitionTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let recognizedText = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionID == requestID else { return }
                    if let recognizedText, !recognizedText.isEmpty {
                        self.transcript = self.combinedText(with: recognizedText)
                    }
                    if let error {
                        let failure = error as NSError
                        Self.logger.error(
                            "Recognition failed: \(failure.domain, privacy: .public) code \(failure.code)"
                        )
                        self.errorMessage = L10n.voiceInputFailed
                    }
                    if isFinal || error != nil {
                        self.stop()
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            self.audioEngine = audioEngine
            recognitionRequest = request
            isRecording = true
        } catch {
            guard recognitionID == requestID else {
                Self.deactivateRecordingSession(requestID: requestID)
                return
            }
            let failure = error as NSError
            Self.logger.error(
                "Recording failed to start: \(failure.domain, privacy: .public) code \(failure.code)"
            )
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            request.endAudio()
            inputCleanup(audioEngine: audioEngine, requestID: requestID)
            errorMessage = L10n.voiceInputFailed
        }
    }

    private func inputCleanup(audioEngine: AVAudioEngine, requestID: UUID) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        Self.deactivateRecordingSession(requestID: requestID)
    }

    private nonisolated static func activateRecordingSession(requestID: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            audioSessionQueue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(
                        .record,
                        mode: .measurement,
                        options: [.duckOthers, .allowBluetoothHFP]
                    )
                    try session.setActive(true)
                    activeAudioSessionID = requestID
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func deactivateRecordingSession(requestID: UUID) {
        audioSessionQueue.async {
            guard activeAudioSessionID == requestID else { return }
            activeAudioSessionID = nil
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    private func combinedText(with recognizedText: String) -> String {
        guard !baseText.isEmpty else { return recognizedText }
        return "\(baseText) \(recognizedText)"
    }

    private static func authorizationMessage(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied:
            L10n.voiceInputDenied
        case .restricted:
            L10n.voiceInputRestricted
        case .notDetermined:
            L10n.voiceInputNotReady
        case .authorized:
            L10n.voiceInputReady
        @unknown default:
            L10n.voiceInputUnavailable
        }
    }
}

// AVAudioEngine delivers tap buffers off the main actor. The Speech request is
// intentionally passed only to its append API from that callback.
private final class SpeechAudioRequestSink: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(_ request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }
}

private extension Character {
    /// A Chinese or Japanese character, which dictation hears without spaces.
    var isIdeograph: Bool { unicodeScalars.first?.properties.isIdeographic ?? false }
}
#endif
