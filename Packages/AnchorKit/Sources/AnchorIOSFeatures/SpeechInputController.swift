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
        guard !isRecording else { return }
        errorMessage = nil
        baseText = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = baseText

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized else {
                    self.errorMessage = Self.authorizationMessage(for: status)
                    return
                }
                self.beginRecognition()
            }
        }
    }

    func stop() {
        guard isRecording || audioEngine != nil else { return }
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func beginRecognition() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            errorMessage = L10n.voiceInputUnavailable
            return
        }

        stop()
        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let recognizedText = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                Task { @MainActor [weak self] in
                    guard let self else { return }
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
        @unknown default:
            L10n.voiceInputUnavailable
        }
    }
}
#endif
