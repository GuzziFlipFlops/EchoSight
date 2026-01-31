import AVFoundation
import Combine
import Foundation
import Speech

final class LiveTranscriptionService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var error: String?

    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let processingQueue = DispatchQueue(label: "echosight.speech.stream")

    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        continuation.resume(returning: true)
                    case .denied, .restricted, .notDetermined:
                        continuation.resume(returning: false)
                    @unknown default:
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    func start() -> Bool {
        guard let recognizer else {
            error = "Speech recognition is unavailable for this language."
            isListening = false
            return false
        }
        guard recognizer.isAvailable else {
            error = "Speech recognition is unavailable on this device."
            isListening = false
            return false
        }

        transcript = ""
        error = nil
        task?.cancel()
        task = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        } else {
            error = "On-device speech recognition isn't available. Captions are disabled."
            isListening = false
            return false
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    self.isListening = true
                }
            }
            if let error {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isListening = false
                }
            }
        }
        isListening = true
        return true
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        processingQueue.async { [weak self] in
            self?.request?.append(buffer)
        }
    }

    func stop() {
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
}
