// MARK: - File Guide
// The home screen is the app's feature launcher. It reads saved settings,
// shows only enabled tools, and routes each card to its feature folder.

import SwiftUI

// HomeScreen.swift is the main feature launcher.
// Guide for the team:
// - HomeView is the feature launcher.
// - Camera pages connect UI controls to the Vision/Core ML view models.
// - Mic pages use Features/Mic for audio capture and captions.
// - Morse, Browser, Settings, Tutorial, and ASL now live in their own folders.
struct HomeView: View {
    // AppFlow is injected from RootView and lets this screen jump to onboarding
    // again if the user opens the tutorial hub.
    @EnvironmentObject var flow: AppFlow
    // These @AppStorage values are backed by UserDefaults, so Settings changes
    // immediately control which feature tiles are shown on the home screen.
    @AppStorage("feature.camera.enabled") private var cameraEnabled: Bool = true
    @AppStorage("feature.mic.enabled") private var micEnabled: Bool = true
    @AppStorage("feature.browser.enabled") private var browserEnabled: Bool = true
    @AppStorage("feature.asl.enabled") private var aslEnabled: Bool = true
    @AppStorage("feature.morse.enabled") private var morseEnabled: Bool = true
    // Startup preferences let Siri Shortcuts or Settings send the user directly
    // to a tool after launch.
    @AppStorage("startup.open.enabled") private var openOnStartup: Bool = false
    @AppStorage("startup.open.tile") private var startupTile: String = StartupTile.none.rawValue
    // The selected theme color is read here and passed down through tint/env.
    @AppStorage("theme.color") private var themeColorName: String = ThemeColor.blue.rawValue
    // autoOpenTile drives a hidden NavigationLink. didAutoOpen prevents repeated
    // pushes when SwiftUI re-runs onAppear.
    @State private var autoOpenTile: Bool = false
    @State private var didAutoOpen: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Assist Tools")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)

                    // Each feature checks its saved enabled flag. This lets
                    // Settings simplify the app for different users.
                    if cameraEnabled {
                        TileLink(title: "Camera", subtitle: "Recognize with camera", systemImage: "camera.viewfinder", destination: AnyView(CameraPage()))
                    }
                    if micEnabled {
                        TileLink(title: "Mic", subtitle: "Speak & listen", systemImage: "mic.fill", destination: AnyView(MicPage()))
                    }
                    if browserEnabled {
                        TileLink(title: "Browser", subtitle: "Browse content", systemImage: "safari.fill", destination: AnyView(BrowserPage()))
                    }
                    if aslEnabled {
                        TileLink(title: "ASL Learning", subtitle: "Learn American Sign Language", systemImage: "hand.raised.fill", destination: AnyView(ASLAlphabetPage()))
                    }
                    if morseEnabled {
                        TileLink(title: "Morse Communicator", subtitle: "communicate in morse signals", systemImage: "antenna.radiowaves.left.and.right", destination: AnyView(MorseCommunicatorPage()))
                    }
                    TileLink(title: "Practice", subtitle: "Daily ASL and Morse lessons", systemImage: "target", destination: AnyView(PracticeHubPage()))

                    Text("More")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                        .padding(.top, 4)

                    TileLink(title: "Activity History", subtitle: "Recent detections, captions, and practice", systemImage: "clock.arrow.circlepath", destination: AnyView(ActivityHistoryPage()))
                    TileLink(title: "Settings", subtitle: "App preferences", systemImage: "gearshape.fill", iconColor: .red, destination: AnyView(SettingsPage()))
                    TileLink(title: "Accessibility", subtitle: "Accessibility options", systemImage: "figure.stand.line.dotted.figure.stand", iconColor: .red, destination: AnyView(AccessibilityPage()))
                    TileLink(title: "Tutorial", subtitle: "View the tutorial again", systemImage: "book.pages.fill", iconColor: .red, destination: AnyView(TutorialHubPage()))
                    TileLink(title: "About", subtitle: "Learn about EchoSight", systemImage: "info.circle.fill", iconColor: .red, destination: AnyView(AboutPage()))
                }
                .padding()
                .padding(.top, 8)
            }
            .navigationTitle("EchoSight")
            .background(EchoSightBackground())
            .background(
                // Hidden NavigationLink is the SwiftUI pattern used here for
                // programmatic startup navigation.
                NavigationLink(destination: startupDestination, isActive: $autoOpenTile) {
                    EmptyView()
                }
                .hidden()
            )
            .tint(themeColor)
            .onAppear {
                // This runs once per app launch screen appearance. It respects
                // both the startup toggle and whether that target feature exists.
                guard openOnStartup, !didAutoOpen else { return }
                didAutoOpen = true
                if startupIsAvailable {
                    autoOpenTile = true
                }
            }
        }
    }

    private var startupSelection: StartupTile {
        // If UserDefaults has an old or invalid string, fall back to no auto-open.
        StartupTile(rawValue: startupTile) ?? .none
    }

    private var startupIsAvailable: Bool {
        // Prevents auto-opening disabled tools. Example: if Camera is off in
        // Settings, a saved "camera" startup choice should not navigate there.
        switch startupSelection {
        case .none:
            return false
        case .camera:
            return cameraEnabled
        case .mic:
            return micEnabled
        case .browser:
            return browserEnabled
        case .asl:
            return aslEnabled
        case .morse:
            return morseEnabled
        }
    }

    @ViewBuilder
    private var startupDestination: some View {
        // @ViewBuilder lets this computed property return different view types
        // from the switch without wrapping everything manually.
        switch startupSelection {
        case .camera:
            CameraPage()
        case .mic:
            MicPage()
        case .browser:
            BrowserPage()
        case .asl:
            ASLAlphabetPage()
        case .morse:
            MorseCommunicatorPage()
        case .none:
            EmptyView()
        }
    }

    private var themeColor: Color {
        // Unknown saved colors fall back to blue so the UI always has a tint.
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }
}

// Used by Settings and Siri Shortcuts to decide which tool opens on launch.
enum StartupTile: String, CaseIterable, Identifiable {
    case none
    case camera
    case mic
    case browser
    case asl
    case morse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .camera:
            return "Camera"
        case .mic:
            return "Mic"
        case .browser:
            return "Browser"
        case .asl:
            return "ASL Learning"
        case .morse:
            return "Morse Communicator"
        }
    }
}

// App-wide accent color choices stored with @AppStorage.
enum ThemeColor: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case teal
    case pink
    case purple
    case indigo
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .teal: return "Teal"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .indigo: return "Indigo"
        case .red: return "Red"
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .teal: return .teal
        case .pink: return .pink
        case .purple: return .purple
        case .indigo: return .indigo
        case .red: return .red
        }
    }
}

private struct AppThemeColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var appThemeColor: Color {
        get { self[AppThemeColorKey.self] }
        set { self[AppThemeColorKey.self] = newValue }
    }
}
