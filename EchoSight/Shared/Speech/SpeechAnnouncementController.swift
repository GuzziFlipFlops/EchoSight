// MARK: - File Guide
// Central speech output system. It manages AVSpeechSynthesizer settings,
// prevents repeated announcements, and gives features one simple speak API.

import AVFoundation
import Combine
import Foundation

// SpeechAnnouncementController.swift contains reusable spoken feedback logic.
// It turns short app status strings into debounced AVSpeechSynthesizer output.

// Speaks short assistive messages with Apple's AVSpeechSynthesizer.
// This powers audio feedback like "Person ahead" or "Detected: $20".
final class SpeechAnnouncer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // Shared instance is available for simple screens that do not need separate control.
    static let shared = SpeechAnnouncer()

    // Apple's speech engine. It queues AVSpeechUtterance objects.
    private let synthesizer = AVSpeechSynthesizer()
    // Debounce state prevents repeated frame-by-frame announcements.
    private var lastPhrase: String = ""
    private var lastSpokenAt: Date = .distantPast
    private let debounceInterval: TimeInterval = 1.8
    // Stored so speech can restart with new slider settings.
    private var lastSpokenText: String = ""
    // Lets AnnouncementController know when speech finished and pending text can run.
    var onQueueFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ phrase: String) {
        // Camera pages call this for short status phrases.
        speak(phrase, debounce: true)
    }

    func speak(
        _ text: String,
        rate: Double? = nil,
        pitch: Double? = nil,
        volume: Double? = nil,
        debounce: Bool = false,
        interrupt: Bool = true
    ) {
        // Skip empty text so the synthesizer queue stays clean.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastSpokenText = trimmed
        let now = Date()
        // If the same phrase was just spoken, do not repeat it.
        if debounce, trimmed == lastPhrase, now.timeIntervalSince(lastSpokenAt) < debounceInterval {
            return
        }
        lastPhrase = trimmed
        lastSpokenAt = now

        prepareAudioSessionForSpeech()

        let sentences = splitSentences(from: trimmed)
        let voice = preferredVoice()
        let settings = SpeechSettings.load()
        // Page-specific values override saved settings only for this call.
        let finalRate = rate ?? settings.rate
        let finalPitch = pitch ?? settings.pitch
        let finalVolume = volume ?? settings.volume

        if interrupt {
            // Stop stale speech before announcing a new detection.
            synthesizer.stopSpeaking(at: .immediate)
        }
        for sentence in sentences {
            // Sentence splitting gives clearer pauses for longer OCR text.
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.voice = voice
            utterance.rate = Float(finalRate)
            utterance.pitchMultiplier = Float(finalPitch)
            utterance.volume = Float(finalVolume)
            utterance.postUtteranceDelay = 0.2
            synthesizer.speak(utterance)
        }
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    func restartIfSpeaking(rate: Double, pitch: Double, volume: Double) {
        // Used by sliders so changes apply immediately while speech is active.
        guard synthesizer.isSpeaking, !lastSpokenText.isEmpty else { return }
        speak(lastSpokenText, rate: rate, pitch: pitch, volume: volume, debounce: false)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func testVoice() {
        speak("This is a voice test for EchoSight.")
    }

    private func prepareAudioSessionForSpeech() {
        // Configure audio so spoken feedback can mix with or duck other audio.
        let session = AVAudioSession.sharedInstance()
        let preferredOptions: AVAudioSession.CategoryOptions = [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        let fallbackOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: preferredOptions)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            do {
                // Fallback is less specialized but more likely to succeed.
                try session.setCategory(.playback, mode: .default, options: fallbackOptions)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                // If the session can't be set, we still allow the synthesizer to try to speak.
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !synthesizer.isSpeaking {
                self.onQueueFinished?()
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !synthesizer.isSpeaking {
                self.onQueueFinished?()
            }
        }
    }

    private func splitSentences(from text: String) -> [String] {
        // Split on punctuation/newlines so long text is spoken in manageable chunks.
        var sentences: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if ".?!\n".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }
        let remaining = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }
        return sentences
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        // Respect Settings voice choice first, otherwise match the device locale.
        let settings = SpeechSettings.load()
        if settings.voiceIdentifier != SpeechSettings.autoVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            return voice
        }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let localeIdentifier = Locale.current.identifier
        let languageCode = Locale.current.languageCode ?? "en"

        let candidates = voices.filter { $0.language == localeIdentifier }
        let fallback = voices.filter { $0.language.hasPrefix(languageCode) }
        let pool = candidates.isEmpty ? fallback : candidates
        return bestVoice(from: pool) ?? bestVoice(from: voices)
    }

    private func bestVoice(from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        // Prefer enhanced voices when available because they sound more natural.
        guard !voices.isEmpty else { return nil }
        return voices.max { lhs, rhs in
            qualityScore(lhs) < qualityScore(rhs)
        }
    }

    private func qualityScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .enhanced:
            return 2
        case .default:
            return 1
        @unknown default:
            return 1
        }
    }
}

// Stored speech preferences shared by settings and all read-aloud tools.
struct SpeechSettings {
    // Centralized UserDefaults keys keep SettingsPage and SpeechAnnouncer aligned.
    static let voiceIdentifierKey = "speech.voice.identifier"
    static let rateKey = "speech.rate"
    static let pitchKey = "speech.pitch"
    static let volumeKey = "speech.volume"
    static let autoVoiceIdentifier = "auto"

    var voiceIdentifier: String
    var rate: Double
    var pitch: Double
    var volume: Double

    static func load() -> SpeechSettings {
        // Defaults keep speech usable the first time the app launches.
        let defaults = UserDefaults.standard
        let voice = defaults.string(forKey: voiceIdentifierKey) ?? autoVoiceIdentifier
        let rate = defaults.object(forKey: rateKey) as? Double ?? 0.5
        let pitch = defaults.object(forKey: pitchKey) as? Double ?? 1.0
        let volume = defaults.object(forKey: volumeKey) as? Double ?? 0.9
        return SpeechSettings(voiceIdentifier: voice, rate: rate, pitch: pitch, volume: volume)
    }
}

// Prevents rapid repeated announcements from stacking up while frames stream in.
final class AnnouncementController: ObservableObject {
    // Wrapped announcer does the actual speech. This class decides when to speak.
    private let announcer: SpeechAnnouncer
    // Same text must wait this long before being announced again.
    private let debounceInterval: TimeInterval = 2.6
    // Different non-priority messages are spaced out for clarity.
    private let cooldownInterval: TimeInterval = 1.8
    private var lastSpokenText: String = ""
    private var lastSpokenAt: Date = .distantPast
    private var lastFinishedAt: Date = .distantPast
    // Pending message stores one delayed announcement while the synthesizer is busy.
    private var pendingMessage: String?
    private var pendingPriority: Bool = false
    private var pendingWork: DispatchWorkItem?

    init(announcer: SpeechAnnouncer = SpeechAnnouncer()) {
        self.announcer = announcer
        announcer.onQueueFinished = { [weak self] in
            // When speech finishes, the controller decides whether pending text can play.
            self?.handleFinished()
        }
    }

    func announce(_ text: String, priority: Bool? = nil) {
        // Camera model strings are cleaned before any speech scheduling.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let isPriority = priority ?? isHighPriority(trimmed)
        let now = Date()
        // Ignore repeated text inside the debounce window.
        if trimmed == lastSpokenText, now.timeIntervalSince(lastSpokenAt) < debounceInterval {
            return
        }
        // If the same thing is still being spoken, do not queue a duplicate.
        if announcer.isSpeaking, trimmed == lastSpokenText {
            return
        }

        if announcer.isSpeaking {
            if isPriority {
                // Safety-related messages interrupt current speech.
                clearPending()
                startSpeaking(trimmed, interrupt: true)
            } else {
                // Non-priority text waits its turn.
                pendingMessage = trimmed
                pendingPriority = isPriority
            }
            return
        }

        let cooldownRemaining = max(0, cooldownInterval - now.timeIntervalSince(lastFinishedAt))
        if cooldownRemaining > 0, !isPriority {
            // Speech just ended, so schedule this after the cooldown.
            pendingMessage = trimmed
            pendingPriority = isPriority
            schedulePending(after: cooldownRemaining)
            return
        }

        startSpeaking(trimmed, interrupt: true)
    }

    func stop() {
        // Used when a page disappears so no old messages keep talking.
        clearPending()
        announcer.stop()
    }

    private func startSpeaking(_ text: String, interrupt: Bool) {
        // Save spoken text for future duplicate/cooldown checks.
        lastSpokenText = text
        lastSpokenAt = Date()
        announcer.speak(text, debounce: false, interrupt: interrupt)
    }

    private func handleFinished() {
        // Mark the finish time for cooldown math.
        lastFinishedAt = Date()
        guard let pendingMessage else { return }
        let priority = pendingPriority
        clearPending()
        let cooldownRemaining = max(0, cooldownInterval - Date().timeIntervalSince(lastFinishedAt))
        if cooldownRemaining > 0, !priority {
            // Pending non-priority text still obeys cooldown.
            schedulePending(after: cooldownRemaining, message: pendingMessage)
        } else {
            startSpeaking(pendingMessage, interrupt: true)
        }
    }

    private func schedulePending(after delay: TimeInterval, message: String? = nil) {
        // Replace any older delayed work with the newest pending message.
        pendingWork?.cancel()
        let messageToSpeak = message ?? pendingMessage
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // If speech restarted, drop this work item and let the next change reschedule.
            guard !self.announcer.isSpeaking else { return }
            if let messageToSpeak {
                self.pendingMessage = nil
                self.pendingPriority = false
                self.pendingWork = nil
                self.startSpeaking(messageToSpeak, interrupt: true)
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func clearPending() {
        // Cancel delayed speech and clear pending flags.
        pendingWork?.cancel()
        pendingWork = nil
        pendingMessage = nil
        pendingPriority = false
    }

    private func isHighPriority(_ text: String) -> Bool {
        // Words that imply immediate action are treated as priority speech.
        let lower = text.lowercased()
        if lower.contains("do not walk") || lower.contains("don't walk") {
            return true
        }
        let keywords = ["stairs", "car", "vehicle", "bus", "truck"]
        return keywords.contains { lower.contains($0) }
    }
}
