// MARK: - File Guide
// Contains the camera user interfaces: object detection, text reader,
// currency identifier, people detection, crosswalk signals, and guidance.

import SwiftUI

// Submenu for all visual accessibility tools.
struct CameraPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Camera tools are split into separate pages so each page can own
                // its own CameraManager and stop capture when dismissed.
                TileLink(
                    title: "Object Detection",
                    subtitle: "Detect objects and announce direction",
                    systemImage: "viewfinder",
                    destination: AnyView(ObjectDetectionPage())
                )
                TileLink(
                    title: "Text Reader (OCR)",
                    subtitle: "Capture text and read aloud",
                    systemImage: "doc.text.viewfinder",
                    destination: AnyView(TextReaderPage())
                )
                TileLink(
                    title: "Currency Identifier",
                    subtitle: "Identify denominations offline",
                    systemImage: "dollarsign.circle",
                    destination: AnyView(CurrencyIdentifierPage())
                )
                TileLink(
                    title: "Nearby People Detection",
                    subtitle: "Describe relative position only",
                    systemImage: "person.2.circle",
                    destination: AnyView(NearbyPeoplePage())
                )
                TileLink(
                    title: "Crosswalk Signal Detection",
                    subtitle: "Walk / Do Not Walk status",
                    systemImage: "figure.walk",
                    destination: AnyView(CrosswalkSignalPage())
                )
                TileLink(
                    title: "Path Guidance (Experimental)",
                    subtitle: "Simple left/right guidance",
                    systemImage: "arrow.left.and.right.circle",
                    destination: AnyView(PathGuidancePage())
                )
            }
            .padding()
        }
        .navigationTitle("Camera Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .background(EchoSightBackground())
    }
}

// MARK: - Camera Accessibility Features
private struct CameraPreviewCard: View {
    // The preview card handles three states: error, active camera, and waiting
    // for permission. Feature pages do not repeat that logic.
    @ObservedObject var camera: CameraManager
    let title: String

    var body: some View {
        ZStack {
            if let cameraError = camera.cameraError {
                // Simulator or permission errors are shown inline instead of
                // crashing or leaving a blank preview.
                VStack(spacing: 8) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(cameraError)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if camera.isAuthorized, camera.hasCameraInput {
                // The actual camera preview is a UIKit layer wrapped in SwiftUI.
                CameraPreview(session: camera.session)
                    .accessibilityLabel(title)
            } else {
                // Permission has not been granted yet or setup is still running.
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Camera access is required.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.secondary.opacity(0.12), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CameraStatusCard: View {
    // Displays the latest human-readable result from a camera view model.
    let title: String
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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

private struct DiagnosticsOverlay: View {
    // Developer-facing metrics that help explain performance to judges.
    let info: DiagnosticsInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Diagnostics")
                .font(.caption.weight(.semibold))
            Text("Model: \(info.modelName)")
                .font(.caption2)
            Text("FPS: \(String(format: "%.1f", info.fps))")
                .font(.caption2)
            Text("Inference: \(String(format: "%.1f", info.inferenceMs)) ms")
                .font(.caption2)
            Text("Compute: \(info.computeUnits)")
                .font(.caption2)
            Text("ANE Allowed: \(info.usesNeuralEngine ? "Yes" : "No")")
                .font(.caption2)
            if !info.topDetections.isEmpty {
                Text("Top: \(info.topDetections.joined(separator: ", "))")
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}


// Live camera page that streams sampled frames into ObjectDetectionViewModel.
struct ObjectDetectionPage: View {
    // StateObject keeps one instance alive for the lifetime of this page.
    @StateObject private var camera = CameraManager()
    // View model owns Vision/Core ML object detection and publishes statusText.
    @StateObject private var viewModel = ObjectDetectionViewModel()
    // AnnouncementController prevents repeated spoken messages from piling up.
    @StateObject private var announcer = AnnouncementController()
    // Local toggles affect only this page session.
    @State private var audioFeedback: Bool = true
    @State private var showDiagnostics: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    CameraPreviewCard(camera: camera, title: "Object Detection Preview")
                    if showDiagnostics {
                        DiagnosticsOverlay(info: viewModel.diagnostics)
                            .padding(12)
                    }
                }
                CameraStatusCard(title: "Detected Object", status: viewModel.statusText)
                Toggle("Audio feedback", isOn: $audioFeedback)
                    .padding(.horizontal)
                Toggle("Show diagnostics", isOn: $showDiagnostics)
                    .padding(.horizontal)
                Text("On-device only. No images leave your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Object Detection")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            // Connect camera frames to the detector only while the page is visible.
            viewModel.diagnosticsEnabled = showDiagnostics
            camera.configure()
            camera.onSampleBuffer = { [weak viewModel] sample in
                viewModel?.process(sampleBuffer: sample)
            }
            camera.start()
        }
        .onChange(of: showDiagnostics) { enabled in
            // Avoid spending time updating metrics unless the overlay is visible.
            viewModel.diagnosticsEnabled = enabled
        }
        .onChange(of: viewModel.statusText) { newValue in
            // "Looking" and "no clear" are status messages, not useful history.
            guard !newValue.localizedCaseInsensitiveContains("looking"),
                  !newValue.localizedCaseInsensitiveContains("no clear") else {
                return
            }
            // Saved activity lets the Activity History page explain what happened.
            ActivityHistoryStore.shared.add(.object, title: "Object Detection", detail: newValue)
            if audioFeedback {
                announcer.announce(newValue)
            }
        }
        .onChange(of: camera.isAuthorized) { authorized in
            // Permission can arrive after configure(), so start once it flips true.
            if authorized { camera.start() }
        }
        .onDisappear {
            // Stop camera and speech to save battery and avoid background work.
            camera.onSampleBuffer = nil
            camera.stop()
            announcer.stop()
        }
    }
}

// OCR page: preview continuously, but recognize text only when the user taps capture.
struct TextReaderPage: View {
    // The page keeps the latest preview frame, then OCR runs when capture is tapped.
    @StateObject private var camera = CameraManager()
    @StateObject private var speech = SpeechAnnouncer()
    @StateObject private var viewModel = TextReaderViewModel()
    @State private var audioFeedback: Bool = true
    @State private var speechRate: Double = 0.5
    @State private var speechPitch: Double = 1.0
    @State private var speechVolume: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CameraPreviewCard(camera: camera, title: "Text Reader Preview")

                Button {
                    viewModel.capture()
                } label: {
                    Label("Capture Text", systemImage: "camera.circle")
                }
                .buttonStyle(PressableButtonStyle(prominent: true))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recognized Text")
                        .font(.headline)
                    Text(viewModel.recognizedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                HStack(spacing: 12) {
                    Button {
                        speech.speak(viewModel.recognizedText, rate: speechRate, pitch: speechPitch, volume: speechVolume)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(PressableButtonStyle(prominent: true))
                    Button {
                        speech.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                    }
                    .buttonStyle(PressableButtonStyle(prominent: false))
                    Button {
                        speech.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(PressableButtonStyle(prominent: false))
                }

                Toggle("Auto read after capture", isOn: $audioFeedback)
                    .padding(.horizontal)
                MorseSettingSlider(title: "Speech rate", value: $speechRate, range: 0.3...0.7, suffix: "")
                MorseSettingSlider(title: "Speech pitch", value: $speechPitch, range: 0.7...1.3, suffix: "")
                MorseSettingSlider(title: "Speech volume", value: $speechVolume, range: 0.2...1.0, suffix: "")
                Text("On-device only. OCR runs locally using Vision.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                // Vision OCR runs in TextReaderViewModel after the user taps Capture.
            }
            .padding()
        }
        .navigationTitle("Text Reader")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            // update(sampleBuffer:) stores the latest frame but does not OCR yet.
            camera.configure()
            camera.onSampleBuffer = { [weak viewModel] sample in
                viewModel?.update(sampleBuffer: sample)
            }
            camera.start()
        }
        .onChange(of: viewModel.recognizedText) { newValue in
            // Once OCR publishes new text, log it and optionally read it aloud.
            ActivityHistoryStore.shared.add(.readText, title: "Text Reader", detail: newValue)
            if audioFeedback {
                speech.speak(newValue, rate: speechRate, pitch: speechPitch, volume: speechVolume, debounce: true)
            }
        }
        .onChange(of: speechRate) { _ in
            // If the user tweaks speech settings mid-sentence, restart with them.
            speech.restartIfSpeaking(rate: speechRate, pitch: speechPitch, volume: speechVolume)
        }
        .onChange(of: speechPitch) { _ in
            speech.restartIfSpeaking(rate: speechRate, pitch: speechPitch, volume: speechVolume)
        }
        .onChange(of: speechVolume) { _ in
            speech.restartIfSpeaking(rate: speechRate, pitch: speechPitch, volume: speechVolume)
        }
        .onChange(of: camera.isAuthorized) { authorized in
            if authorized { camera.start() }
        }
        .onDisappear {
            // Releasing the sample callback breaks the frame pipeline cleanly.
            camera.onSampleBuffer = nil
            camera.stop()
            speech.stop()
        }
    }
}

// Currency page: uses OCR/model evidence and waits for a stable result before speaking.
struct CurrencyIdentifierPage: View {
    // Same camera pattern as object detection, but with denomination-specific
    // evidence and stricter confidence/stability requirements.
    @StateObject private var camera = CameraManager()
    @StateObject private var viewModel = CurrencyIdentifierViewModel()
    @StateObject private var announcer = AnnouncementController()
    @State private var audioFeedback: Bool = true
    @State private var showDiagnostics: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    CameraPreviewCard(camera: camera, title: "Currency Identifier Preview")
                    if showDiagnostics {
                        DiagnosticsOverlay(info: viewModel.diagnostics)
                            .padding(12)
                    }
                }
                CameraStatusCard(title: "Denomination", status: viewModel.statusText)
                Toggle("Audio feedback", isOn: $audioFeedback)
                    .padding(.horizontal)
                Toggle("Show diagnostics", isOn: $showDiagnostics)
                    .padding(.horizontal)
                Text("On-device only. No images leave your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Text("Uses the bundled classifier when available; otherwise OCR confirms denomination text and numbers across frames.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Currency Identifier")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            // update(sampleBuffer:) throttles internally so the UI stays smooth.
            viewModel.diagnosticsEnabled = showDiagnostics
            camera.configure()
            camera.onSampleBuffer = { [weak viewModel] sample in
                viewModel?.update(sampleBuffer: sample)
            }
            camera.start()
        }
        .onChange(of: showDiagnostics) { enabled in
            viewModel.diagnosticsEnabled = enabled
        }
        .onChange(of: viewModel.statusText) { newValue in
            // Only final detections are spoken/logged. "Hold bill steady" is just guidance.
            guard newValue.hasPrefix("Detected: $") else { return }
            ActivityHistoryStore.shared.add(.object, title: "Currency Identifier", detail: newValue)
            if audioFeedback {
                announcer.announce(newValue)
            }
        }
        .onChange(of: camera.isAuthorized) { authorized in
            if authorized { camera.start() }
        }
        .onDisappear {
            camera.onSampleBuffer = nil
            camera.stop()
            announcer.stop()
        }
    }
}

// Relative people detection page. It intentionally avoids identity or face recognition.
struct NearbyPeoplePage: View {
    // Uses Vision's person rectangle detection; no identity or face data is used.
    @StateObject private var camera = CameraManager()
    @StateObject private var viewModel = PeopleDetectionViewModel()
    @StateObject private var announcer = AnnouncementController()
    @State private var audioFeedback: Bool = true
    @State private var showDiagnostics: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    CameraPreviewCard(camera: camera, title: "Nearby People Preview")
                    if showDiagnostics {
                        DiagnosticsOverlay(info: viewModel.diagnostics)
                            .padding(12)
                    }
                }
                CameraStatusCard(title: "Relative Position", status: viewModel.statusText)
                Toggle("Audio feedback", isOn: $audioFeedback)
                    .padding(.horizontal)
                Toggle("Show diagnostics", isOn: $showDiagnostics)
                    .padding(.horizontal)
                Text("No face recognition or tracking. Only relative positions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                // PeopleDetectionViewModel reports relative positions only, not identity.
            }
            .padding()
        }
        .navigationTitle("Nearby People")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.diagnosticsEnabled = showDiagnostics
            camera.configure()
            camera.onSampleBuffer = { [weak viewModel] sample in
                viewModel?.process(sampleBuffer: sample)
            }
            camera.start()
        }
        .onChange(of: showDiagnostics) { enabled in
            viewModel.diagnosticsEnabled = enabled
        }
        .onChange(of: viewModel.statusText) { newValue in
            // Nearby people messages are logged as object-style camera activity.
            ActivityHistoryStore.shared.add(.object, title: "Nearby People", detail: newValue)
            if audioFeedback {
                announcer.announce(newValue)
            }
        }
        .onChange(of: camera.isAuthorized) { authorized in
            if authorized { camera.start() }
        }
        .onDisappear {
            camera.onSampleBuffer = nil
            camera.stop()
            announcer.stop()
        }
    }
}

// Future-ready page for a traffic signal model.
struct CrosswalkSignalPage: View {
    // Placeholder-ready page: currently uses available local model hooks if present.
    @StateObject private var camera = CameraManager()
    @StateObject private var viewModel = CrosswalkSignalViewModel()
    @StateObject private var announcer = AnnouncementController()
    @State private var audioFeedback: Bool = true
    @State private var showDiagnostics: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    CameraPreviewCard(camera: camera, title: "Crosswalk Signal Preview")
                    if showDiagnostics {
                        DiagnosticsOverlay(info: viewModel.diagnostics)
                            .padding(12)
                    }
                }
                CameraStatusCard(title: "Crosswalk Signal", status: viewModel.statusText)
                Toggle("Audio feedback", isOn: $audioFeedback)
                    .padding(.horizontal)
                Toggle("Show diagnostics", isOn: $showDiagnostics)
                    .padding(.horizontal)
                Text("On-device only. No video is stored.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                // CrosswalkSignalViewModel is ready for an optional bundled classifier.
            }
            .padding()
        }
        .navigationTitle("Crosswalk Signal")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.diagnosticsEnabled = showDiagnostics
            camera.configure()
            camera.onSampleBuffer = { [weak viewModel] sample in
                viewModel?.process(sampleBuffer: sample)
            }
            camera.start()
        }
        .onChange(of: showDiagnostics) { enabled in
            viewModel.diagnosticsEnabled = enabled
        }
        .onChange(of: viewModel.statusText) { newValue in
            ActivityHistoryStore.shared.add(.object, title: "Crosswalk Signal", detail: newValue)
            if audioFeedback {
                announcer.announce(newValue)
            }
        }
        .onChange(of: camera.isAuthorized) { authorized in
            if authorized { camera.start() }
        }
        .onDisappear {
            camera.onSampleBuffer = nil
            camera.stop()
            announcer.stop()
        }
    }
}

// Experimental page for rough left/right guidance, not full navigation.
struct PathGuidancePage: View {
    // Rough brightness-based guidance used as an experimental local fallback.
    @StateObject private var camera = CameraManager()
    @StateObject private var viewModel = PathGuidanceViewModel()
    @StateObject private var announcer = AnnouncementController()
    @State private var audioFeedback: Bool = true
    @State private var showDiagnostics: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    CameraPreviewCard(camera: camera, title: "Path Guidance Preview")
                    if showDiagnostics {
                        DiagnosticsOverlay(info: viewModel.diagnostics)
                            .padding(12)
                    }
                }
                CameraStatusCard(title: "Guidance (Experimental)", status: viewModel.statusText)
                Toggle("Audio feedback", isOn: $audioFeedback)
                    .padding(.horizontal)
                Toggle("Show diagnostics", isOn: $showDiagnostics)
                    .padding(.horizontal)
                Text("Experimental feature. Guidance is approximate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                // PathGuidanceViewModel is an approximate heuristic, not full navigation.
            }
            .padding()
        }
        .navigationTitle("Path Guidance")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.diagnosticsEnabled = showDiagnostics
            camera.configure()
            camera.onSampleBuffer = { [weak viewModel] sample in
                viewModel?.process(sampleBuffer: sample)
            }
            camera.start()
        }
        .onChange(of: showDiagnostics) { enabled in
            viewModel.diagnosticsEnabled = enabled
        }
        .onChange(of: viewModel.statusText) { newValue in
            ActivityHistoryStore.shared.add(.object, title: "Path Guidance", detail: newValue)
            // Directional guidance can also trigger watch/phone assist alerts.
            if newValue.localizedCaseInsensitiveContains("left") || newValue.localizedCaseInsensitiveContains("right") {
                AssistAlertCenter.shared.alert(.obstacle, message: newValue)
            }
            if audioFeedback {
                announcer.announce(newValue)
            }
        }
        .onChange(of: camera.isAuthorized) { authorized in
            if authorized { camera.start() }
        }
        .onDisappear {
            camera.onSampleBuffer = nil
            camera.stop()
            announcer.stop()
        }
    }
}
