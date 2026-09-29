#if os(iOS)
import AnchorDesign
import AVFAudio
import Observation
import Speech

@MainActor
@Observable
final class SpeechInputController {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var isRequestingPermission = false
    private var recognitionID = UUID()
    private(set) var audioLevel = 0.0
    private var lastMeterUpdate = Date.distantPast
    private(set) var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var baseText = ""

    func toggle(initialText: String) {
        if isRecording {
            stop()
        } else {
            start(initialText: initialText)
        }
    }

    func start(initialText: String) {
        guard !isRecording, !isRequestingPermission else { return }
        recognitionID = UUID()
        let requestID = recognitionID
        isRequestingPermission = true
        errorMessage = nil
        baseText = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = baseText

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, self.recognitionID == requestID else { return }
                self.isRequestingPermission = false
                guard status == .authorized else {
                    self.errorMessage = Self.authorizationMessage(for: status)
                    return
                }
                self.beginRecognition(requestID: requestID)
            }
        }
    }

    func stop() {
        // Invalidate permission and recognition callbacks before changing segments.
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
        audioLevel = 0
    }

    func clearError() {
        errorMessage = nil
    }

    private func beginRecognition(requestID: UUID) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            errorMessage = L10n.voiceInputUnavailable
            return
        }

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request, weak self] buffer, _ in
                request?.append(buffer)
                guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
                var energy: Float = 0
                for index in 0..<Int(buffer.frameLength) { energy += samples[index] * samples[index] }
                let level = min(1, Double(sqrt(energy / Float(buffer.frameLength))) * 8)
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionID == requestID,
                          Date.now.timeIntervalSince(self.lastMeterUpdate) > 0.08 else { return }
                    self.lastMeterUpdate = .now
                    self.audioLevel = level
                }
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let recognizedText = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionID == requestID else { return }
                    if let recognizedText, !recognizedText.isEmpty {
                        self.transcript = self.combinedText(with: recognizedText)
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
            inputCleanup(audioEngine: audioEngine)
            errorMessage = L10n.voiceInputFailed
        }
    }

    private func inputCleanup(audioEngine: AVAudioEngine) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
#endif
