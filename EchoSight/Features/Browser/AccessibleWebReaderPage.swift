// MARK: - File Guide
// Accessible browser/reader. Combines WKWebView, text extraction, speech
// playback, and simple controls so web content is easier to consume.

import AVFoundation
import Combine
import SwiftUI
import UIKit
import WebKit

// Simple microphone loudness meter used by browser/voice-adjacent controls.
final class AudioMeter: ObservableObject {
    // This lightweight meter is separate from MicViewModel because browser pages
    // only need a simple 0...1 loudness value.
    private let engine = AVAudioEngine()
    @Published var level: CGFloat = 0 // 0...1

    func start() {
        // Measurement mode gives cleaner loudness readings and ducks other audio.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            return
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        // A tap copies mic buffers out of AVAudioEngine for RMS processing.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        do {
            try engine.start()
        } catch {
            // Unable to start engine
        }
    }

    func stop() {
        // Removing the tap is important before stopping the engine.
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func process(buffer: AVAudioPCMBuffer) {
        // RMS converts the audio waveform into a single loudness number.
        guard let channelData = buffer.floatChannelData?.pointee else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0
        for frameIndex in 0..<frameLength {
            let audioSample = channelData[frameIndex]
            sum += audioSample * audioSample
        }
        let rms = sqrt(sum / Float(frameLength))
        var db: Float = -80
        if rms > 0 { db = 20 * log10(rms) }
        let minDb: Float = -80
        let clamped = max(minDb, db)
        let normalized = (clamped - minDb) / -minDb // 0..1

        DispatchQueue.main.async {
            // Published values must update on the main thread for SwiftUI.
            self.level = CGFloat(normalized)
        }
    }
}

// Accessible browser with reader styling, speech, and auto-scroll controls.
struct BrowserPage: View {
    // URL and focus state drive the top address bar.
    @State private var urlText: String = ""
    @FocusState private var urlFieldFocused: Bool
    // Reader settings are local state so changes preview immediately.
    @State private var textSize: Double = 16
    @State private var lineSpacing: Double = 1.4
    @State private var highContrast: Bool = false
    @State private var highlightLinks: Bool = true
    @State private var simplifyPage: Bool = true
    @State private var simplifyIntensity: Double = 0.6
    @State private var focusMode: Bool = false
    // Auto-scroll uses a timer inside WebReaderModel.
    @State private var autoScroll: Bool = false
    @State private var autoScrollSpeed: Double = 1.2
    // Read-aloud state uses AVSpeechSynthesizer through WebReaderModel.
    @State private var readerEnabled: Bool = true
    @State private var speechRate: Double = 0.48
    @State private var webViewHeight: Double = 520
    // Starter sites are accessibility-related resources for demos.
    @State private var savedSites: [String] = [
        "https://nfb.org/",
        "https://www.acb.org/home",
        "https://www.nad.org/",
        "https://webaim.org/"
    ]
    @StateObject private var readerModel = WebReaderModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("URL")
                        .font(.headline)
                    HStack(spacing: 8) {
                        TextField("Enter a website URL", text: $urlText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($urlFieldFocused)
                            .onSubmit {
                                loadFromURLText()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        Button("Paste") {
                            if let clipboard = UIPasteboard.general.string {
                                urlText = clipboard
                                loadFromURLText()
                            }
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))
                    }
                    HStack(spacing: 10) {
                        Button {
                            loadFromURLText()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Go")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: true))

                        Button {
                            readerModel.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))
                        .disabled(!readerModel.canGoBack)

                        Button {
                            readerModel.goForward()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))
                        .disabled(!readerModel.canGoForward)

                        Button {
                            readerModel.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))

                        Button {
                            readerModel.stop()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))
                        .disabled(!readerModel.isLoading)

                        Spacer()

                        Button {
                            saveCurrentURL()
                        } label: {
                            Image(systemName: "bookmark")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: true))
                    }
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

                WebReaderView(
                    model: readerModel,
                    urlText: $urlText,
                    readerEnabled: $readerEnabled,
                    textSize: $textSize,
                    lineSpacing: $lineSpacing,
                    highContrast: $highContrast,
                    highlightLinks: $highlightLinks,
                    simplifyPage: $simplifyPage,
                    simplifyIntensity: $simplifyIntensity,
                    focusMode: $focusMode,
                    autoScroll: $autoScroll,
                    autoScrollSpeed: $autoScrollSpeed
                )
                .frame(height: webViewHeight)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.secondary.opacity(0.12), lineWidth: 1)
                        )
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved Sites")
                        .font(.headline)
                    if savedSites.isEmpty {
                        Text("No saved sites yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedSites, id: \.self) { site in
                            HStack(spacing: 10) {
                                Button {
                                    urlText = site
                                    loadFromURLText()
                                } label: {
                                    HStack {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundStyle(.tint)
                                        Text(site)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    removeSavedSite(site)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(PressableButtonStyle(prominent: false))
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(.secondary.opacity(0.12), lineWidth: 1)
                                    )
                            )
                        }
                    }
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

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable reader controls", isOn: $readerEnabled)
                        .font(.headline)
                    if readerEnabled {
                        MorseSettingSlider(title: "Text size", value: $textSize, range: 12...28, suffix: "pt")
                        MorseSettingSlider(title: "Line spacing", value: $lineSpacing, range: 1.0...2.2, suffix: "")
                        Toggle("High contrast", isOn: $highContrast)
                        Toggle("Highlight links", isOn: $highlightLinks)
                        Toggle("Simplify page", isOn: $simplifyPage)
                        if simplifyPage {
                            MorseSettingSlider(title: "Simplify intensity", value: $simplifyIntensity, range: 0...1, suffix: "")
                        }
                        Toggle("Auto-scroll", isOn: $autoScroll)
                        if autoScroll {
                            MorseSettingSlider(title: "Auto-scroll speed", value: $autoScrollSpeed, range: 0.5...3.0, suffix: "x")
                        }
                        MorseSettingSlider(title: "Web view height", value: $webViewHeight, range: 360...900, suffix: "pt")
                    } else {
                        Text("Reader controls are off. Pages render normally.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Read Aloud (TTS)")
                        .font(.headline)
                    Text(readerModel.currentSpokenLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            readerModel.skipWord(-1, rate: Float(speechRate))
                        } label: {
                            Image(systemName: "backward.fill")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))

                        Button {
                            readerModel.startSpeaking(rate: Float(speechRate))
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: true))

                        Button {
                            readerModel.pauseSpeaking()
                        } label: {
                            Image(systemName: "pause.fill")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))

                        Button {
                            readerModel.resumeSpeaking()
                        } label: {
                            Image(systemName: "gobackward")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))

                        Button {
                            readerModel.stopSpeaking()
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))

                        Button {
                            readerModel.skipWord(1, rate: Float(speechRate))
                        } label: {
                            Image(systemName: "forward.fill")
                        }
                        .buttonStyle(PressableButtonStyle(prominent: false))
                    }
                    MorseSettingSlider(title: "Speech rate", value: $speechRate, range: 0.3...0.7, suffix: "")
                    Text("Bonus: Read selection (long-press text)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Accessibility Features")
                        .font(.headline)
                    Toggle("Focus mode (one paragraph at a time)", isOn: $focusMode)
                    Toggle("Tap to define / tap to spell", isOn: .constant(false))
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
        .navigationTitle("Web Reader")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            urlFieldFocused = false
        }
        .onChange(of: speechRate) { newValue in
            if readerModel.isSpeaking {
                readerModel.restartSpeaking(rate: Float(newValue))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    urlFieldFocused = false
                }
            }
        }
    }

    private func saveCurrentURL() {
        // Normalize before saving so "example.com" and "https://example.com" match.
        guard let normalized = normalizedURL(from: urlText) else { return }
        if !savedSites.contains(normalized) {
            savedSites.append(normalized)
        }
        urlText = normalized
        readerModel.load(urlString: normalized)
    }

    private func removeSavedSite(_ site: String) {
        // Simple local array removal. This list is not persisted yet.
        savedSites.removeAll { $0 == site }
    }

    private func loadFromURLText() {
        // Shared by Go button, return key, saved-site taps, and paste.
        guard let normalized = normalizedURL(from: urlText) else { return }
        urlText = normalized
        readerModel.load(urlString: normalized)
    }

    private func normalizedURL(from text: String) -> String? {
        // WebKit needs a scheme; add https when the user types a bare domain.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
    }
}

// Owns WKWebView state plus read-aloud behavior so BrowserPage stays declarative.
private final class WebReaderModel: NSObject, ObservableObject, WKNavigationDelegate, AVSpeechSynthesizerDelegate {
    // Published navigation state controls toolbar buttons and labels.
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var currentSpokenLabel: String = "Not reading"
    @Published var isSpeaking: Bool = false

    // The actual WKWebView is created by WebReaderView, then attached here.
    private(set) var webView: WKWebView?
    private let synthesizer = AVSpeechSynthesizer()
    // Timer scrolls the web page in tiny steps while auto-scroll is enabled.
    private var autoScrollTimer: Timer?
    // Last settings are reapplied after each page navigation finishes.
    private var lastSettings = WebReaderSettings()
    // Cached text lets skip/back work without re-running JavaScript every tap.
    private var cachedText: String = ""
    private var cachedWords: [String] = []
    private var currentWordIndex: Int = 0
    // Index in cachedWords where the current speech utterance began.
    private var utteranceStartIndex: Int = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func attach(webView: WKWebView) {
        // Store the view and receive navigation callbacks.
        self.webView = webView
        webView.navigationDelegate = self
    }

    func load(urlString: String) {
        // Load accepts either full URLs or bare domains.
        guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stop() {
        webView?.stopLoading()
    }

    func applyReaderSettings(
        enabled: Bool,
        textSize: Double,
        lineSpacing: Double,
        highContrast: Bool,
        highlightLinks: Bool,
        simplifyPage: Bool,
        simplifyIntensity: Double,
        focusMode: Bool
    ) {
        // Save settings so they can be reapplied after navigation.
        lastSettings = WebReaderSettings(
            enabled: enabled,
            textSize: textSize,
            lineSpacing: lineSpacing,
            highContrast: highContrast,
            highlightLinks: highlightLinks,
            simplifyPage: simplifyPage,
            simplifyIntensity: simplifyIntensity,
            focusMode: focusMode
        )
        let js = """
        (function() {
            // This script injects one <style> tag and edits classes/selectors.
            // It does not send page content anywhere; it only changes rendering locally.
            const id = 'echosight-reader-style';
            let style = document.getElementById(id);
            if (!\(enabled)) {
                if (style) style.remove();
                document.body.classList.remove('echosight-reader');
                document.documentElement.classList.remove('echosight-invert');
                return;
            }
            if (!style) {
                style = document.createElement('style');
                style.id = id;
                document.head.appendChild(style);
            }
            const linkSize = \(highlightLinks) ? 1.08 : 1.0;
            const linkUnderline = \(highlightLinks) ? 'underline' : 'none';
            const contrast = '#111';
            const bg = '#f9f9f9';
            style.textContent = `
                html, body {
                    background: ${bg} !important;
                }
                body.echosight-reader {
                    font-size: \(textSize)px !important;
                    line-height: \(lineSpacing) !important;
                    color: ${contrast} !important;
                }
                body.echosight-reader a {
                    text-decoration: ${linkUnderline} !important;
                    font-size: ${linkSize}em !important;
                    padding: 2px 2px !important;
                }
                html.echosight-invert {
                    filter: invert(1) hue-rotate(180deg) !important;
                    background: #000 !important;
                }
            `;
            document.body.classList.add('echosight-reader');
            if (\(highContrast)) {
                document.documentElement.classList.add('echosight-invert');
            } else {
                document.documentElement.classList.remove('echosight-invert');
            }
            if (\(simplifyPage)) {
                const intensity = \(simplifyIntensity);
                const hideSelectors = [
                    'nav','header','footer','aside','[role="navigation"]','[role="banner"]',
                    '[role="contentinfo"]','.sidebar','.nav','.menu','.ads','.ad','.promo'
                ];
                if (intensity > 0.5) {
                    hideSelectors.push('.share','.social','.related','.newsletter','.subscribe','.comments');
                }
                if (intensity > 0.8) {
                    // At high simplify levels, hide media-heavy elements.
                    hideSelectors.push('img','video','iframe','picture');
                }
                hideSelectors.forEach(sel => {
                    document.querySelectorAll(sel).forEach(el => el.style.display = 'none');
                });
                if (intensity >= 0.95) {
                    // Maximum simplification replaces the page with extracted text.
                    const existing = document.getElementById('echosight-text-only');
                    const main = document.querySelector('main, article, [role="main"]') || document.body;
                    const text = main.innerText || '';
                    if (!existing) {
                        document.body.innerHTML = '';
                        const wrap = document.createElement('div');
                        wrap.id = 'echosight-text-only';
                        wrap.style.maxWidth = '48rem';
                        wrap.style.margin = '0 auto';
                        wrap.style.padding = '24px';
                        const disclaimer = document.createElement('div');
                        disclaimer.textContent = 'Disclaimer: only text (max simplification).';
                        disclaimer.style.fontWeight = '600';
                        disclaimer.style.marginBottom = '12px';
                        const content = document.createElement('div');
                        content.style.whiteSpace = 'pre-wrap';
                        content.textContent = text;
                        wrap.appendChild(disclaimer);
                        wrap.appendChild(content);
                        document.body.appendChild(wrap);
                    } else {
                        existing.querySelector('div:nth-child(2)').textContent = text;
                    }
                }
            }
            if (\(focusMode)) {
                const main = document.querySelector('main, article, [role="main"]') || document.body;
                main.style.maxWidth = '48rem';
                main.style.margin = '0 auto';
            }
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func setAutoScroll(enabled: Bool, speed: Double) {
        // Reset timer every time settings change so speed updates immediately.
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        guard enabled else { return }
        let clamped = max(0.2, min(speed, 6.0))
        let interval = 0.08
        let step = clamped * 2
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Scroll happens inside WebKit via JavaScript.
            self?.webView?.evaluateJavaScript("window.scrollBy(0, \(step));", completionHandler: nil)
        }
    }

    func startSpeaking(rate: Float) {
        // Read the page text, cache it, and speak starting from currentWordIndex.
        extractReadableText { [weak self] text in
            guard let self, let text, !text.isEmpty else { return }
            self.cacheText(text)
            self.speakFrom(index: self.currentWordIndex, rate: rate)
            DispatchQueue.main.async {
                self.isSpeaking = true
            }
        }
    }

    func pauseSpeaking() {
        // Pause keeps AVSpeechSynthesizer's internal position.
        synthesizer.pauseSpeaking(at: .word)
        isSpeaking = false
    }

    func resumeSpeaking() {
        // Continue from the paused AVSpeechSynthesizer position.
        synthesizer.continueSpeaking()
        isSpeaking = true
    }

    func stopSpeaking() {
        // Stop resets the status label but keeps cached text for later.
        synthesizer.stopSpeaking(at: .immediate)
        currentSpokenLabel = "Stopped"
        isSpeaking = false
    }

    func restartSpeaking(rate: Float) {
        // Used when the speech-rate slider changes mid-read.
        guard isSpeaking else { return }
        speakFrom(index: currentWordIndex, rate: rate)
    }

    func skipWord(_ delta: Int, rate: Float) {
        // Move by one word and restart speech from the new index.
        ensureCachedText { [weak self] in
            guard let self else { return }
            guard !self.cachedWords.isEmpty else { return }
            let newIndex = min(max(self.currentWordIndex + delta, 0), self.cachedWords.count - 1)
            self.currentWordIndex = newIndex
            self.speakFrom(index: newIndex, rate: rate)
        }
    }

    private func extractReadableText(completion: @escaping (String?) -> Void) {
        // Prefer semantic main/article text, falling back to body text.
        let js = """
        (function() {
            const main = document.querySelector('main, article, [role="main"]');
            return (main ? main.innerText : document.body.innerText);
        })();
        """
        webView?.evaluateJavaScript(js) { result, _ in
            completion(result as? String)
        }
    }

    private func ensureCachedText(_ completion: @escaping () -> Void) {
        // Avoid repeated JavaScript extraction when cached text is still valid.
        if !cachedText.isEmpty {
            completion()
            return
        }
        extractReadableText { [weak self] text in
            guard let self, let text, !text.isEmpty else { return }
            self.cacheText(text)
            completion()
        }
    }

    private func cacheText(_ text: String) {
        // Store both raw text and a word array for navigation.
        cachedText = text
        cachedWords = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map { String($0) }
        if cachedWords.isEmpty {
            currentWordIndex = 0
        } else {
            currentWordIndex = min(currentWordIndex, cachedWords.count - 1)
        }
        updateCurrentSpokenLabel()
    }

    private func speakFrom(index: Int, rate: Float) {
        // AVSpeechSynthesizer cannot start at a word index, so we speak the suffix.
        guard !cachedWords.isEmpty else { return }
        let clamped = min(max(index, 0), cachedWords.count - 1)
        currentWordIndex = clamped
        utteranceStartIndex = clamped
        let remainder = cachedWords[clamped...].joined(separator: " ")
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: remainder)
        utterance.rate = rate
        synthesizer.speak(utterance)
        updateCurrentSpokenLabel()
    }

    private func updateCurrentSpokenLabel() {
        // Keeps the UI synchronized with the current word.
        guard !cachedWords.isEmpty, currentWordIndex < cachedWords.count else {
            currentSpokenLabel = "Not reading"
            return
        }
        currentSpokenLabel = "Reading: \(cachedWords[currentWordIndex]) (\(currentWordIndex + 1)/\(cachedWords.count))"
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Convert the character range in the spoken suffix back into cachedWords index.
        let text = utterance.speechString as NSString
        let prefix = text.substring(to: characterRange.location)
        let wordsBefore = prefix.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let current = utteranceStartIndex + wordsBefore
        if current >= 0, current < cachedWords.count {
            currentWordIndex = current
            updateCurrentSpokenLabel()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Mark reading stopped when the utterance naturally ends.
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Update toolbar button state as navigation begins.
        isLoading = true
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // New page means cached speech text is stale.
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        cachedText = ""
        cachedWords = []
        currentWordIndex = 0
        currentSpokenLabel = "Not reading"
        applyReaderSettings(
            // Reapply accessibility styling after the new DOM loads.
            enabled: lastSettings.enabled,
            textSize: lastSettings.textSize,
            lineSpacing: lastSettings.lineSpacing,
            highContrast: lastSettings.highContrast,
            highlightLinks: lastSettings.highlightLinks,
            simplifyPage: lastSettings.simplifyPage,
            simplifyIntensity: lastSettings.simplifyIntensity,
            focusMode: lastSettings.focusMode
        )
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Stop showing the loading state after navigation failure.
        isLoading = false
    }
}

private struct WebReaderSettings {
    // Plain data container for all reader CSS/behavior controls.
    var enabled: Bool = true
    var textSize: Double = 16
    var lineSpacing: Double = 1.4
    var highContrast: Bool = false
    var highlightLinks: Bool = true
    var simplifyPage: Bool = true
    var simplifyIntensity: Double = 0.6
    var focusMode: Bool = false
}

private struct WebReaderView: UIViewRepresentable {
    // UIViewRepresentable is needed because WKWebView is a UIKit view.
    @ObservedObject var model: WebReaderModel
    @Binding var urlText: String
    @Binding var readerEnabled: Bool
    @Binding var textSize: Double
    @Binding var lineSpacing: Double
    @Binding var highContrast: Bool
    @Binding var highlightLinks: Bool
    @Binding var simplifyPage: Bool
    @Binding var simplifyIntensity: Double
    @Binding var focusMode: Bool
    @Binding var autoScroll: Bool
    @Binding var autoScrollSpeed: Double

    func makeUIView(context: Context) -> WKWebView {
        // Create WebKit once, attach it to the model, and optionally load a URL.
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor.systemBackground
        model.attach(webView: webView)
        if !urlText.isEmpty {
            model.load(urlString: urlText)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // SwiftUI calls this whenever bindings change, so reader settings stay live.
        model.applyReaderSettings(
            enabled: readerEnabled,
            textSize: textSize,
            lineSpacing: lineSpacing,
            highContrast: highContrast,
            highlightLinks: highlightLinks,
            simplifyPage: simplifyPage,
            simplifyIntensity: simplifyIntensity,
            focusMode: focusMode
        )
        model.setAutoScroll(enabled: autoScroll, speed: autoScrollSpeed)
    }
}
