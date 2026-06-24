// MARK: - File Guide
// Settings, accessibility preferences, and About screens. Most options save
// through @AppStorage, so the app updates immediately when toggles change.

import AVFoundation
import SwiftUI

struct SettingsAccessibilityPage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand.line.dotted.figure.stand")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Settings & Accessibility coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

struct AccessibilityPage: View {
    @AppStorage("accessibility.simplifiedUI") private var simplifiedUI: Bool = false
    @AppStorage("accessibility.simplifiedUI.includeRed") private var simplifyRedTiles: Bool = false

    var body: some View {
        Form {
            Section("Simplified UI") {
                Toggle("Simplified UI", isOn: $simplifiedUI)
                Toggle("Apply to red tiles", isOn: $simplifyRedTiles)
                    .disabled(!simplifiedUI)
                Text("Simplified UI removes icons and subtitles on Home tiles and enlarges titles. Red tiles will use red backgrounds; others use blue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Devices") {
                NavigationLink("Connect EchoSense Device") {
                    EchoSenseDevicePage()
                }
                Text("Bluetooth pairing and configuration are coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EchoSenseDevicePage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("EchoSense Device")
                .font(.title2.bold())
            Text("Bluetooth pairing and device configuration are coming soon.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("EchoSense")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// User-facing feature toggles and persistent preferences.
struct SettingsPage: View {
    @AppStorage("feature.camera.enabled") private var cameraEnabled: Bool = true
    @AppStorage("feature.morse.enabled") private var morseEnabled: Bool = true
    @AppStorage("feature.browser.enabled") private var browserEnabled: Bool = true
    @AppStorage("feature.asl.enabled") private var aslEnabled: Bool = true
    @AppStorage("feature.mic.enabled") private var micEnabled: Bool = true
    @AppStorage("startup.open.enabled") private var openOnStartup: Bool = false
    @AppStorage("startup.open.tile") private var startupTile: String = StartupTile.none.rawValue
    @AppStorage("theme.color") private var themeColorName: String = ThemeColor.blue.rawValue
    @AppStorage(SpeechSettings.voiceIdentifierKey) private var speechVoiceIdentifier: String = SpeechSettings.autoVoiceIdentifier
    @AppStorage(SpeechSettings.rateKey) private var speechRate: Double = 0.5

    var body: some View {
        Form {
            Section("Visual Features") {
                Toggle("Camera", isOn: $cameraEnabled)
                Toggle("Morse Communicator", isOn: $morseEnabled)
                Toggle("Browser", isOn: $browserEnabled)
            }
            Section("Auditory Features") {
                Toggle("ASL Alphabet", isOn: $aslEnabled)
                Toggle("Mic", isOn: $micEnabled)
            }
            Section("Appearance") {
                Picker("Theme color", selection: $themeColorName) {
                    ForEach(ThemeColor.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            }
            Section("Speech") {
                Picker("Voice", selection: $speechVoiceIdentifier) {
                    Text("Auto (best match)").tag(SpeechSettings.autoVoiceIdentifier)
                    ForEach(availableVoices(), id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))")
                            .tag(voice.identifier)
                    }
                }
                MorseSettingSlider(title: "Speech rate", value: $speechRate, range: 0.3...0.7, suffix: "")
                Button("Test Voice") {
                    SpeechAnnouncer.shared.testVoice()
                }
                Text("Tip: Download enhanced voices in Settings → Accessibility → Spoken Content → Voices.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy & Device Alerts") {
                Label("Offline-first camera, OCR, mic analysis, ASL, and Morse tools", systemImage: "lock.shield.fill")
                Label("iPhone haptics are active for Morse, practice, obstacle, and sound alerts", systemImage: "iphone.radiowaves.left.and.right")
                Label("Apple Watch relay is ready when a companion watch app is installed", systemImage: "applewatch")
                Text("EchoSight does not upload camera frames for its critical assist tools.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Open tile on start-up", isOn: $openOnStartup)
                if openOnStartup {
                    Picker("Tile", selection: $startupTile) {
                        ForEach(StartupTile.allCases) { tile in
                            Text(tile.title).tag(tile.rawValue)
                        }
                    }
                }
                Text("Select a feature tile to open automatically when EchoSight starts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func availableVoices() -> [AVSpeechSynthesisVoice] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let locale = Locale.current.identifier
        let language = Locale.current.languageCode ?? "en"
        let preferred = voices.filter { $0.language == locale }
        let fallback = voices.filter { $0.language.hasPrefix(language) }
        let list = preferred.isEmpty ? fallback : preferred
        return list.sorted { $0.name < $1.name }
    }
}

struct AboutPage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("EchoSight\nCreated by the EchoSight team.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("version 5.0.22")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}
