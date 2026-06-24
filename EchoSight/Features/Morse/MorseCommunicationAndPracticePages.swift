// MARK: - File Guide
// Morse feature screens. Users can enter dots/dashes, convert text to Morse,
// play output with sound/haptics, and study Morse letters/numbers.

import Combine
import CoreHaptics
import SwiftUI
import UIKit

// Morse hub: input, output, practice, and reference charts.
struct MorseCommunicatorPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // The hub presents Morse as learn, input, output, practice, reference.
                // This is easier to demo than placing all controls on one page.
                TileLink(
                    title: "How to Use Morse",
                    subtitle: "Learn dots, dashes, and spacing",
                    systemImage: "questionmark.circle.fill",
                    destination: AnyView(MorseTutorialPage())
                )
                TileLink(
                    title: "Morse Input",
                    subtitle: "Tap to translate into text",
                    systemImage: "hand.tap.fill",
                    destination: AnyView(MorseInputPage())
                )
                TileLink(
                    title: "Morse Output",
                    subtitle: "Type text to play vibrations",
                    systemImage: "waveform.path.ecg",
                    destination: AnyView(MorseOutputPage())
                )
                TileLink(
                    title: "Morse Practice",
                    subtitle: "Daily streaks and lessons",
                    systemImage: "target",
                    destination: AnyView(PracticeHubPage())
                )
                TileLink(
                    title: "Morse Letters",
                    subtitle: "Browse A–Z symbols",
                    systemImage: "textformat.abc",
                    destination: AnyView(MorseLettersPage())
                )
                TileLink(
                    title: "Morse Numbers",
                    subtitle: "Browse 0–9 symbols",
                    systemImage: "number",
                    destination: AnyView(MorseNumbersPage())
                )
            }
            .padding()
        }
        .navigationTitle("Morse Communicator")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// Lets the user tap dots/dashes and converts Morse symbols into text.
struct MorseInputPage: View {
    // The Morse symbols for the letter currently being entered, such as ".-".
    @State private var currentSymbols: String = ""
    // The decoded message built from committed Morse letters.
    @State private var outputText: String = ""
    // Raw dot/dash history, useful for learning and judge demos.
    @State private var rawStream: String = ""
    // Press state measures gesture duration for dot versus dash.
    @State private var isPressing: Bool = false
    @State private var pressStart: Date?
    // Delayed commit timers separate letters and words based on pauses.
    @State private var letterCommitWork: DispatchWorkItem?
    @State private var wordCommitWork: DispatchWorkItem?

    // User-tunable timing thresholds make the app work for different tapping speeds.
    @State private var dotThreshold: Double = 0.18
    @State private var dashThreshold: Double = 0.35
    @State private var letterGap: Double = 0.6
    @State private var wordGap: Double = 1.2
    // Haptic toggles persist because some users prefer quieter feedback.
    @AppStorage("morse.input.haptic.dot") private var hapticDotEnabled: Bool = true
    @AppStorage("morse.input.haptic.dash") private var hapticDashEnabled: Bool = true
    @Environment(\.appThemeColor) private var appThemeColor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap to enter Morse")
                        .font(.headline)
                    Text("Short tap = dot, long press = dash. Pauses separate letters and words.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isPressing ? appThemeColor.opacity(0.2) : Color.secondary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(appThemeColor.opacity(0.2), lineWidth: 1)
                        )
                        .frame(height: 240)

                    VStack(spacing: 8) {
                        Text(isPressing ? "Release to finish tap" : "Tap and hold here")
                            .font(.title3.weight(.semibold))
                        Text(currentSymbols.isEmpty ? "Current input: —" : "Current input: \(currentSymbols)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressing {
                                beginPress()
                            }
                        }
                        .onEnded { _ in
                            endPress()
                        }
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Output")
                            .font(.headline)
                        Spacer()
                        Button("Reset") {
                            resetOutput()
                        }
                        .buttonStyle(.bordered)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Raw stream")
                            .font(.subheadline.weight(.semibold))
                        Text(rawStreamDisplay())
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Decoded text")
                            .font(.subheadline.weight(.semibold))
                        Text(outputText.isEmpty ? "Output will appear here as you tap." : outputText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Input Settings")
                        .font(.headline)

                    MorseSettingSlider(
                        title: "Dot max duration",
                        value: $dotThreshold,
                        range: 0.05...0.4,
                        suffix: "s"
                    )
                    MorseSettingSlider(
                        title: "Dash min duration",
                        value: $dashThreshold,
                        range: 0.2...0.9,
                        suffix: "s"
                    )
                    MorseSettingSlider(
                        title: "Letter gap",
                        value: $letterGap,
                        range: 0.2...1.5,
                        suffix: "s"
                    )
                    MorseSettingSlider(
                        title: "Word gap",
                        value: $wordGap,
                        range: 0.6...2.5,
                        suffix: "s"
                    )
                    Toggle("Haptic tick for dots", isOn: $hapticDotEnabled)
                    Toggle("Haptic tick for dashes", isOn: $hapticDashEnabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.secondary.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .padding()
        }
        .navigationTitle("Morse Input")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onChange(of: dotThreshold) { newValue in
            // Keep thresholds from crossing so every press maps to one symbol.
            if newValue >= dashThreshold - 0.05 {
                dotThreshold = max(0.05, dashThreshold - 0.05)
            }
        }
        .onChange(of: dashThreshold) { newValue in
            // Maintain a small gap between dot and dash timing.
            if newValue <= dotThreshold + 0.05 {
                dashThreshold = min(0.9, dotThreshold + 0.05)
            }
        }
    }

    private func beginPress() {
        // New input cancels old pause timers because the current letter continues.
        isPressing = true
        pressStart = Date()
        letterCommitWork?.cancel()
        wordCommitWork?.cancel()
    }

    private func endPress() {
        // If pressStart is missing, reset safely instead of guessing.
        guard let start = pressStart else {
            isPressing = false
            return
        }
        // The touch duration is the whole Morse input signal.
        let duration = Date().timeIntervalSince(start)
        let symbol = classifySymbol(duration: duration)
        currentSymbols.append(symbol)
        triggerInputHaptic(for: symbol)
        isPressing = false
        scheduleCommitTimers()
    }

    private func classifySymbol(duration: TimeInterval) -> String {
        // Short touch is dot.
        if duration <= dotThreshold {
            return "."
        }
        // Long touch is dash.
        if duration >= dashThreshold {
            return "-"
        }
        // Middle zone chooses the closest threshold, making the control forgiving.
        let midpoint = (dotThreshold + dashThreshold) / 2
        return duration < midpoint ? "." : "-"
    }

    private func scheduleCommitTimers() {
        // Each symbol restarts the silence timers.
        letterCommitWork?.cancel()
        wordCommitWork?.cancel()

        let letterWork = DispatchWorkItem {
            // Pause long enough for a letter: decode current dot/dash group.
            commitCurrentSymbols()
        }
        let wordWork = DispatchWorkItem {
            // Longer pause: commit letter and append a word separator.
            commitCurrentSymbols()
            if !outputText.hasSuffix(" "), !outputText.isEmpty {
                outputText.append(" ")
            }
            if !rawStream.hasSuffix(" / "), !rawStream.isEmpty {
                rawStream.append(" / ")
            }
        }

        letterCommitWork = letterWork
        wordCommitWork = wordWork
        // Timers mutate @State, so they run back on the main queue.
        DispatchQueue.main.asyncAfter(deadline: .now() + letterGap, execute: letterWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + wordGap, execute: wordWork)
    }

    private func commitCurrentSymbols() {
        // Do nothing if a timer fires after everything was already committed.
        guard !currentSymbols.isEmpty else { return }
        if !rawStream.isEmpty, !rawStream.hasSuffix(" / ") {
            rawStream.append(" ")
        }
        rawStream.append(currentSymbols)
        if let character = MorseCodeMap.shared.character(for: currentSymbols) {
            // Known sequence becomes a real letter/number.
            outputText.append(character)
            ActivityHistoryStore.shared.add(.morse, title: "Morse Input", detail: "Decoded \(currentSymbols) as \(character)")
        } else {
            // Unknown sequence remains visible as a question mark for learning.
            outputText.append("?")
            ActivityHistoryStore.shared.add(.morse, title: "Morse Input", detail: "Unknown symbol \(currentSymbols)")
        }
        currentSymbols = ""
    }

    private func resetOutput() {
        // Clear visible state and cancel delayed work so old timers cannot append later.
        currentSymbols = ""
        outputText = ""
        rawStream = ""
        letterCommitWork?.cancel()
        wordCommitWork?.cancel()
    }

    private func rawStreamDisplay() -> String {
        // Include in-progress symbols before the letter timer commits them.
        let combined = rawStream + currentSymbols
        return combined.isEmpty ? "—" : combined
    }

    private func triggerInputHaptic(for symbol: String) {
        // Dot and dash feedback differ in strength so users can feel the difference.
        switch symbol {
        case ".":
            guard hapticDotEnabled else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        case "-":
            guard hapticDashEnabled else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        default:
            break
        }
    }
}

// Converts typed text into Morse audio/haptics so messages can be felt or heard.
struct MorseOutputPage: View {
    // The text the user types before conversion.
    @State private var textToPlay: String = ""
    // Controls the highlighted word chip and progress indicator.
    @State private var selectedWordIndex: Int = 0
    // Async playback task is cancellable for pause/stop.
    @State private var playbackTask: Task<Void, Never>?
    @State private var playbackStatus: PlaybackStatus = .stopped
    // Saves resume progress within word, letter, and symbol.
    @State private var playbackPosition = PlaybackPosition()
    // Token invalidates older async playback loops after restart.
    @State private var playbackToken: Int = 0
    @State private var settings = MorsePlaybackSettings()
    @FocusState private var editorFocused: Bool
    @StateObject private var haptics = MorseHaptics()
    @Environment(\.appThemeColor) private var appThemeColor

    var body: some View {
        let words = parsedWords()
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Type text to play as Morse")
                        .font(.headline)
                    TextEditor(text: $textToPlay)
                        .frame(minHeight: 140)
                        .focused($editorFocused)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                    Text("Your text will be converted into dots and dashes and played using haptics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Playback")
                        .font(.headline)
                    HStack {
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                moveToPreviousWord(in: words)
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                togglePlayback(words: words)
                            } label: {
                                Image(systemName: playbackStatus == .playing ? "pause.fill" : "play.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                moveToNextWord(in: words)
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Now playing")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(currentPlaybackLabel(words: words))
                            .font(.headline)
                        ProgressView(
                            value: words.isEmpty ? 0 : Double(min(selectedWordIndex + 1, words.count)),
                            total: max(Double(words.count), 1)
                        )
                        .opacity(words.isEmpty ? 0.3 : 1.0)
                        Text("Word \(words.isEmpty ? 0 : min(selectedWordIndex + 1, words.count)) of \(words.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Word Navigator")
                        .font(.headline)
                    Text("Tap a word to jump back and replay its Morse output.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if words.isEmpty {
                                Text("Type text above to generate word tiles.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(words.indices, id: \.self) { wordIndex in
                                    let word = words[wordIndex]
                                    Button {
                                        setPlaybackStart(index: wordIndex, words: words)
                                    } label: {
                                        Text(word)
                                            .font(.subheadline)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(
                                                Capsule()
                                                    .fill(selectedWordIndex == wordIndex ? appThemeColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                MorsePlaybackSettingsCard(settings: $settings)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editorFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    editorFocused = false
                }
            }
        }
        .navigationTitle("Morse Output")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onDisappear {
            stopPlayback()
        }
    }

    private func parsedWords() -> [String] {
        // Split on whitespace and remove surrounding punctuation so "Hi!" plays as HI.
        textToPlay
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
            .filter { !$0.isEmpty }
    }

    private func togglePlayback(words: [String]) {
        // One button controls play, pause, and resume based on the current state.
        switch playbackStatus {
        case .playing:
            pausePlayback()
        case .paused:
            resumePlayback(words: words)
        case .stopped:
            startPlayback(from: PlaybackPosition(wordIndex: selectedWordIndex), words: words)
        }
    }

    private func pausePlayback() {
        // Increment token and cancel task so the async loop exits quickly.
        playbackToken += 1
        playbackTask?.cancel()
        playbackTask = nil
        playbackStatus = .paused
        haptics.stop()
    }

    private func stopPlayback() {
        // Stop cancels haptics and stores the current selected word for replay.
        playbackToken += 1
        playbackTask?.cancel()
        playbackTask = nil
        playbackStatus = .stopped
        playbackPosition = PlaybackPosition(wordIndex: selectedWordIndex)
        haptics.stop()
    }

    private func resumePlayback(words: [String]) {
        // Resume starts from the saved word/letter/symbol position.
        startPlayback(from: playbackPosition, words: words)
    }

    private func startPlayback(from position: PlaybackPosition, words: [String]) {
        // Make sure there is only one active playback task at a time.
        stopPlayback()
        guard !words.isEmpty else { return }
        // Clamp handles cases where the text changed and the old index is invalid.
        let clampedWord = min(max(position.wordIndex, 0), words.count - 1)
        playbackPosition = PlaybackPosition(wordIndex: clampedWord, letterIndex: position.letterIndex, symbolIndex: position.symbolIndex)
        selectedWordIndex = clampedWord
        playbackStatus = .playing
        playbackToken += 1
        let token = playbackToken
        ActivityHistoryStore.shared.add(.morse, title: "Morse Output", detail: "Playing \(words.joined(separator: " "))")
        AssistAlertCenter.shared.alert(.morse, message: "Morse playback started")

        playbackTask = Task {
            await haptics.startEngineIfNeeded()
            // Playback is word by word so progress can update clearly.
            for wordIndex in clampedWord..<words.count {
                if Task.isCancelled || token != playbackToken { break }
                let word = words[wordIndex]
                await MainActor.run {
                    selectedWordIndex = wordIndex
                    if playbackPosition.wordIndex != wordIndex {
                        playbackPosition = PlaybackPosition(wordIndex: wordIndex)
                    }
                }

                let startLetterIndex = (wordIndex == clampedWord) ? playbackPosition.letterIndex : 0
                let startSymbolIndex = (wordIndex == clampedWord) ? playbackPosition.symbolIndex : 0
                // playWord handles the letter and symbol timing inside a word.
                await playWord(word, startLetterIndex: startLetterIndex, startSymbolIndex: startSymbolIndex, token: token)

                if Task.isCancelled || token != playbackToken { break }
                if wordIndex < words.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(settings.wordGap * 1_000_000_000))
                }
            }
            await MainActor.run {
                playbackStatus = .stopped
            }
        }
    }

    private func moveToPreviousWord(in words: [String]) {
        // Guard avoids negative indices when there is no text.
        guard !words.isEmpty else { return }
        let newIndex = max(selectedWordIndex - 1, 0)
        setPlaybackStart(index: newIndex, words: words)
    }

    private func moveToNextWord(in words: [String]) {
        // Clamp to the last word to keep navigation safe.
        guard !words.isEmpty else { return }
        let newIndex = min(selectedWordIndex + 1, words.count - 1)
        setPlaybackStart(index: newIndex, words: words)
    }

    private func setPlaybackStart(index: Int, words: [String]) {
        // Word chips use this to jump to a word; if already playing, restart there.
        guard !words.isEmpty else { return }
        let clamped = min(max(index, 0), words.count - 1)
        selectedWordIndex = clamped
        playbackPosition = PlaybackPosition(wordIndex: clamped)
        if playbackStatus == .playing {
            startPlayback(from: playbackPosition, words: words)
        }
    }

    private func currentPlaybackLabel(words: [String]) -> String {
        // Display text for the "Now playing" label.
        guard !words.isEmpty, selectedWordIndex < words.count else { return "—" }
        switch playbackStatus {
        case .paused:
            return "Paused on \(words[selectedWordIndex])"
        case .playing, .stopped:
            return words[selectedWordIndex]
        }
    }

    private func playWord(_ word: String, startLetterIndex: Int, startSymbolIndex: Int, token: Int) async {
        // Morse table supports A-Z and 0-9, so other characters are ignored.
        let letters = word.uppercased().filter { $0.isLetter || $0.isNumber }
        let letterArray = Array(letters)
        guard !letterArray.isEmpty else { return }

        let safeStartLetter = min(max(startLetterIndex, 0), letterArray.count - 1)
        for letterIndex in safeStartLetter..<letterArray.count {
            // Cancellation/token checks make pause and stop responsive.
            if Task.isCancelled || token != playbackToken { return }
            let char = letterArray[letterIndex]
            if let code = MorseCodeMap.shared.code(for: char) {
                let symbols = Array(code)
                // Resume can start in the middle of a letter, so clamp symbol too.
                let safeStartSymbol = min(max(startSymbolIndex, 0), max(symbols.count - 1, 0))
                let symbolStart = (letterIndex == safeStartLetter) ? safeStartSymbol : 0
                for symbolIndex in symbolStart..<symbols.count {
                    if Task.isCancelled || token != playbackToken { return }
                    await MainActor.run {
                        // Progress is SwiftUI state, so write it on MainActor.
                        playbackPosition = PlaybackPosition(wordIndex: selectedWordIndex, letterIndex: letterIndex, symbolIndex: symbolIndex)
                    }
                    let symbol = symbols[symbolIndex]
                    // Dot and dash share intensity/sharpness but use different durations.
                    if symbol == "." {
                        await haptics.play(duration: settings.dotDuration, intensity: settings.intensity, sharpness: settings.sharpness)
                    } else if symbol == "-" {
                        await haptics.play(duration: settings.dashDuration, intensity: settings.intensity, sharpness: settings.sharpness)
                    }
                    if symbolIndex < symbols.count - 1 {
                        // Gap between dots and dashes inside one letter.
                        try? await Task.sleep(nanoseconds: UInt64(settings.elementGap * 1_000_000_000))
                    }
                }
            }
            if letterIndex < letterArray.count - 1 {
                // Gap between letters in the same word.
                try? await Task.sleep(nanoseconds: UInt64(settings.letterGap * 1_000_000_000))
            }
        }
    }
}

private enum PlaybackStatus {
    case stopped
    case playing
    case paused
}

private struct PlaybackPosition: Equatable {
    // Word/letter/symbol indexes let Morse playback pause and resume precisely.
    var wordIndex: Int = 0
    var letterIndex: Int = 0
    var symbolIndex: Int = 0
}

// Central Morse lookup table shared by input, output, and reference charts.
private final class MorseCodeMap {
    // Singleton avoids rebuilding the Morse dictionary in every view.
    static let shared = MorseCodeMap()

    // Official Morse codes for letters and numbers used by input/output/reference.
    private let map: [Character: String] = [
        "A": ".-",    "B": "-...",  "C": "-.-.",  "D": "-..",   "E": ".",
        "F": "..-.",  "G": "--.",   "H": "....",  "I": "..",    "J": ".---",
        "K": "-.-",   "L": ".-..",  "M": "--",    "N": "-.",    "O": "---",
        "P": ".--.",  "Q": "--.-",  "R": ".-.",   "S": "...",   "T": "-",
        "U": "..-",   "V": "...-",  "W": ".--",   "X": "-..-",  "Y": "-.--",
        "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----."
    ]
    private lazy var reverseMap: [String: Character] = {
        // Reverse lookup converts tapped dots/dashes back into letters.
        var reverse: [String: Character] = [:]
        for (key, value) in map {
            reverse[value] = key
        }
        return reverse
    }()

    func code(for character: Character) -> String? {
        // Text-to-Morse lookup.
        map[character]
    }

    func character(for code: String) -> Character? {
        // Morse-to-text lookup.
        reverseMap[code]
    }
}

// Plays Morse timing through Core Haptics when the device supports it.
private final class MorseHaptics: ObservableObject {
    // Core Haptics engine is optional because not every device/simulator supports it.
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    init() {
        guard supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.stoppedHandler = { _ in
            // Engine stops when the app goes to the background; restart on next play.
        }
    }

    func startEngineIfNeeded() async {
        // Lazily start/restart the engine right before playback.
        guard supportsHaptics else { return }
        if engine == nil {
            engine = try? CHHapticEngine()
        }
        if let engine {
            try? await engine.start()
        }
    }

    func stop() {
        // Stop releases active vibration patterns.
        guard supportsHaptics else { return }
        try? engine?.stop()
    }

    func play(duration: TimeInterval, intensity: Double, sharpness: Double) async {
        // Builds one continuous haptic event for a dot or dash.
        guard supportsHaptics, let engine else { return }
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness))
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: duration
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return }
        let player = try? engine.makePlayer(with: pattern)
        try? player?.start(atTime: 0)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}

private struct MorsePlaybackSettings {
    // These defaults follow common Morse timing ratios: dash is about 3 dots.
    var dotDuration: Double = 0.12
    var dashDuration: Double = 0.36
    var elementGap: Double = 0.12
    var letterGap: Double = 0.36
    var wordGap: Double = 0.84
    var intensity: Double = 1.0
    var sharpness: Double = 0.6
}

private struct MorsePlaybackSettingsCard: View {
    // Two-way binding lets sliders edit the parent playback settings directly.
    @Binding var settings: MorsePlaybackSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playback Settings")
                .font(.headline)

            MorseSettingSlider(
                title: "Dot duration",
                value: $settings.dotDuration,
                range: 0.05...0.4,
                suffix: "s"
            )
            MorseSettingSlider(
                title: "Dash duration",
                value: $settings.dashDuration,
                range: 0.1...0.8,
                suffix: "s"
            )
            MorseSettingSlider(
                title: "Element gap",
                value: $settings.elementGap,
                range: 0.05...0.4,
                suffix: "s"
            )
            MorseSettingSlider(
                title: "Letter gap",
                value: $settings.letterGap,
                range: 0.1...0.8,
                suffix: "s"
            )
            MorseSettingSlider(
                title: "Word gap",
                value: $settings.wordGap,
                range: 0.3...1.6,
                suffix: "s"
            )
            MorseSettingSlider(
                title: "Haptic intensity",
                value: $settings.intensity,
                range: 0.2...1.0,
                suffix: ""
            )
            MorseSettingSlider(
                title: "Haptic sharpness",
                value: $settings.sharpness,
                range: 0.1...1.0,
                suffix: ""
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.secondary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}


// MARK: - Morse Letters (A–Z with slider + scroll)
struct MorseLettersPage: View {
    @State private var selectedIndex: Int = 0
    @State private var isDraggingSlider: Bool = false
    @State private var pendingScroll: DispatchWorkItem?
    private let letters: [String] = (0..<26).compactMap { letterOffset in
        guard let scalar = UnicodeScalar(65 + letterOffset) else { return nil }
        return String(Character(scalar))
    }
    private let scrollDebounce: TimeInterval = 0.04

    private func scheduleScroll(to index: Int, proxy: ScrollViewProxy, animated: Bool) {
        pendingScroll?.cancel()
        let work = DispatchWorkItem {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(index, anchor: .top)
                }
            } else {
                proxy.scrollTo(index, anchor: .top)
            }
        }
        pendingScroll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollDebounce, execute: work)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 12) {
                HStack {
                    Text("Letter: \(letters[selectedIndex])")
                        .font(.headline)
                    Spacer()
                }

                Slider(
                    value: Binding(
                        get: { Double(selectedIndex) },
                        set: { sliderValue in
                            let targetLetterIndex = Int(sliderValue.rounded())
                            if targetLetterIndex != selectedIndex {
                                selectedIndex = targetLetterIndex
                                scheduleScroll(to: targetLetterIndex, proxy: proxy, animated: !isDraggingSlider)
                            }
                        }
                    ),
                    in: 0...25,
                    step: 1,
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            scheduleScroll(to: selectedIndex, proxy: proxy, animated: true)
                        }
                    }
                )
                .accessibilityLabel("Select letter")

                Divider().padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(0..<letters.count, id: \.self) { letterIndex in
                            MorseLetterCard(letter: letters[letterIndex], index: letterIndex)
                                .id(letterIndex)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: MorseLetterOffsetKey.self,
                                            value: [letterIndex: geo.frame(in: .named("morseLettersScroll")).minY]
                                        )
                                    }
                                )
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        if isDraggingSlider {
                            isDraggingSlider = false
                        }
                        pendingScroll?.cancel()
                    }
                )
                .coordinateSpace(name: "morseLettersScroll")
                .onPreferenceChange(MorseLetterOffsetKey.self) { offsets in
                    guard !offsets.isEmpty else { return }
                    if isDraggingSlider { return }
                    let targetTop: CGFloat = 20
                    let closest = offsets.min(by: { abs($0.value - targetTop) < abs($1.value - targetTop) })
                    if let closestLetterIndex = closest?.key, closestLetterIndex != selectedIndex {
                        selectedIndex = closestLetterIndex
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Morse Letters")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct MorseLetterOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct MorseLetterCard: View {
    let letter: String
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(letter)
                .font(.headline)
            ZStack {
                Image("Morse_\(letter)")
                    .resizable()
                    .aspectRatio(CGSize(width: 283, height: 25), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("Morse for letter \(letter)")
                    .overlay(
                        Group {
                            if UIImage(named: "Morse_\(letter)") == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.08))
                                    VStack(spacing: 6) {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.secondary)
                                        Text("Add image named \"Morse_\(letter)\"")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.secondary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Morse Numbers (0–9 with slider + scroll)
struct MorseNumbersPage: View {
    @State private var selectedIndex: Int = 0
    @State private var isDraggingSlider: Bool = false
    @State private var pendingScroll: DispatchWorkItem?
    private let numbers: [Int] = Array(0...9)
    private let scrollDebounce: TimeInterval = 0.04

    private func scheduleScroll(to index: Int, proxy: ScrollViewProxy, animated: Bool) {
        pendingScroll?.cancel()
        let work = DispatchWorkItem {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(index, anchor: .top)
                }
            } else {
                proxy.scrollTo(index, anchor: .top)
            }
        }
        pendingScroll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollDebounce, execute: work)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 12) {
                HStack {
                    Text("Number: \(numbers[selectedIndex])")
                        .font(.headline)
                    Spacer()
                }

                Slider(
                    value: Binding(
                        get: { Double(selectedIndex) },
                        set: { sliderValue in
                            let targetNumberIndex = Int(sliderValue.rounded())
                            if targetNumberIndex != selectedIndex {
                                selectedIndex = targetNumberIndex
                                scheduleScroll(to: targetNumberIndex, proxy: proxy, animated: !isDraggingSlider)
                            }
                        }
                    ),
                    in: 0...Double(numbers.count - 1),
                    step: 1,
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            scheduleScroll(to: selectedIndex, proxy: proxy, animated: true)
                        }
                    }
                )
                .accessibilityLabel("Select number")

                Divider().padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(0..<numbers.count, id: \.self) { numberIndex in
                            MorseNumberCard(number: numbers[numberIndex], index: numberIndex)
                                .id(numberIndex)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: MorseNumberOffsetKey.self,
                                            value: [numberIndex: geo.frame(in: .named("morseNumbersScroll")).minY]
                                        )
                                    }
                                )
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        if isDraggingSlider {
                            isDraggingSlider = false
                        }
                        pendingScroll?.cancel()
                    }
                )
                .coordinateSpace(name: "morseNumbersScroll")
                .onPreferenceChange(MorseNumberOffsetKey.self) { offsets in
                    guard !offsets.isEmpty else { return }
                    if isDraggingSlider { return }
                    let targetTop: CGFloat = 20
                    let closest = offsets.min(by: { abs($0.value - targetTop) < abs($1.value - targetTop) })
                    if let closestNumberIndex = closest?.key, closestNumberIndex != selectedIndex {
                        selectedIndex = closestNumberIndex
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Morse Numbers")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct MorseNumberOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct MorseNumberCard: View {
    let number: Int
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number)")
                .font(.headline)
            ZStack {
                Image("Morse_\(number)")
                    .resizable()
                    .aspectRatio(CGSize(width: 283, height: 25), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("Morse for number \(number)")
                    .overlay(
                        Group {
                            if UIImage(named: "Morse_\(number)") == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.08))
                                    VStack(spacing: 6) {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.secondary)
                                        Text("Add image named \"Morse_\(number)\"")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.secondary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
