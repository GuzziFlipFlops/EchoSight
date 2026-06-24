// MARK: - File Guide
// Help pages for each feature. These explain Camera, Mic, Browser, Morse,
// and ASL in short plain-language screens.

import SwiftUI

// Menu for quick explanations of each major app tool.
struct TutorialHubPage: View {
    @EnvironmentObject var flow: AppFlow

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Overview tile (launches the original onboarding tutorial)
                ActionTile(title: "Overview", subtitle: "Quick start tutorial", systemImage: "book.closed.fill") {
                    UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
                    flow.phase = .tutorial
                }

                // Extra spacing to isolate the overview tile
                Spacer(minLength: 8)

                // Feature-specific tutorials
                TileLink(title: "Camera", subtitle: "Using camera recognition", systemImage: "camera.viewfinder", destination: AnyView(CameraTutorialPage()))
                TileLink(title: "Mic", subtitle: "Voice and listening tips", systemImage: "mic.fill", destination: AnyView(MicTutorialPage()))
                TileLink(title: "Browser", subtitle: "Browsing with EchoSight", systemImage: "safari.fill", destination: AnyView(BrowserTutorialPage()))
                TileLink(title: "ASL Alphabet", subtitle: "Learn and practice", systemImage: "hand.raised.fill", destination: AnyView(ASLTutorialPage()))
                TileLink(title: "Morse Communicator", subtitle: "Send and receive signals", systemImage: "antenna.radiowaves.left.and.right", destination: AnyView(MorseTutorialPage()))
            }
            .padding()
        }
        .navigationTitle("Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Replace the entire ASLTutorialPage with the new implementation
struct ASLTutorialPage: View {
    private let tips: [(title: String, text: String)] = [
        (
            title: "Topic-Comment Structure",
            text: "In ASL, sentences often follow topic first, then comment. For example, \"Your name what?\" instead of \"What is your name?\" This helps sentences feel natural in sign language."
        ),
        (
            title: "Deaf Etiquette Basics",
            text: "Simple etiquette like getting attention (touch shoulder or wave gently), and always face the signer directly."
        ),
        (
            title: "Facial Expressions Matter",
            text: "Facial movements (eyebrows, mouth) are part of the grammar, not extra gesture. Raised eyebrows often signal a question."
        ),
        (
            title: "Finger Spelling Tips",
            text: "For repeated letters, add a little bounce or slide so it’s easier to read."
        ),
        (
            title: "Handshape & Location",
            text: "ASL signs depend on handshape, palm orientation, and location in signing space — not just motion."
        ),
        (
            title: "Numbers Help",
            text: "Knowing how to sign 1–10 often comes up in everyday ASL."
        ),
        (
            title: "Eye Contact Is Important",
            text: "Maintaining eye contact shows attention and respect and helps communication flow naturally in ASL."
        ),
        (
            title: "Sign in a Neutral Space",
            text: "Most signs happen between the chest and face area; signing too high or too low can reduce clarity."
        ),
        (
            title: "One Concept at a Time",
            text: "ASL often uses fewer signs than English, focusing on key ideas rather than every word."
        ),
        (
            title: "Clarification Is Normal",
            text: "It’s okay to ask someone to repeat or slow down; this is common and expected in ASL conversations."
        ),
        (
            title: "Names Are Fingerspelled",
            text: "People’s names are usually spelled using the ASL alphabet unless they have a name sign."
        ),
        (
            title: "Use Pointing Appropriately",
            text: "Pointing is commonly used in ASL to refer to people or objects and is not considered rude."
        ),
        (
            title: "Speed Comes with Practice",
            text: "Clear, steady signing is better than fast signing when learning ASL."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<tips.count, id: \.self) { i in
                    InfoTile(title: tips[i].title, text: tips[i].text)
                }
            }
            .padding()
        }
        .navigationTitle("ASL Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CameraTutorialPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Camera Overview").font(.title.bold())
                Text("• Point the camera at an object or text.\n• Ensure good lighting for best results.\n• Keep your hands steady; use a stand if needed.\n• Try different distances to improve recognition accuracy.")
                Text("Tips").font(.headline)
                Text("• Avoid glare or reflections.\n• Tap to focus if the subject appears blurry.\n• Use the rear camera for better quality.")
            }
            .padding()
        }
        .navigationTitle("Camera Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MicTutorialPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mic Overview").font(.title.bold())
                Text("• Speak clearly and at a moderate pace.\n• Reduce background noise when possible.\n• Use headphones with a mic for clearer input.")
                Text("Tips").font(.headline)
                Text("• Pause briefly between sentences.\n• If the app isn't responding, check microphone permissions in Settings.")
            }
            .padding()
        }
        .navigationTitle("Mic Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BrowserTutorialPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browser Overview").font(.title.bold())
                Text("• Use the integrated browser to access content within EchoSight.\n• Navigate with the standard back/forward buttons.\n• Use reader mode if available for simplified pages.")
                Text("Tips").font(.headline)
                Text("• Favor accessible websites with semantic markup.\n• Increase text size using system accessibility settings for better readability.")
            }
            .padding()
        }
        .navigationTitle("Browser Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Explains Morse at a presentation level: what dots/dashes mean and how to use them.
struct MorseTutorialPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MorseHeroCard()

                MorseSectionCard(title: "Spacing Is Important", systemImage: "pause.circle.fill") {
                    Text("Morse code does not use a spacebar. Instead, pauses separate signals.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MorseBulletList(items: [
                        "A short pause separates dots and dashes within the same letter",
                        "A medium pause separates letters",
                        "A long pause separates words"
                    ])
                    Text("The app automatically handles these pauses for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                MorseSectionCard(title: "Example", systemImage: "text.quote") {
                    Text("The word “ADD” in Morse code looks like this:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MorseExampleBlock(lines: [
                        "A = · –",
                        "D = – · ·",
                        "",
                        "So “ADD” is sent as:",
                        "· – | – · · | – · ·"
                    ])
                    Text("The longer pauses show where one letter ends and the next begins.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                MorseSectionCard(title: "Using Morse in This App", systemImage: "hand.tap.fill") {
                    MorseBulletList(items: [
                        "Short tap on the screen = dot",
                        "Long press on the screen = dash",
                        "Pause briefly to finish a letter",
                        "Pause longer to finish a word",
                        "Your taps will automatically be translated into text"
                    ])
                }

                MorseSectionCard(title: "Morse Output", systemImage: "waveform.path.ecg") {
                    Text("You can also type text and have it played back as Morse code using vibrations:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MorseBulletList(items: [
                        "Short vibration = dot",
                        "Long vibration = dash"
                    ])
                    Text("This allows communication without sound or speech.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                MorseSectionCard(title: "Who Morse Code Helps", systemImage: "person.2.fill") {
                    MorseBulletList(items: [
                        "Are deafblind",
                        "Have limited speech or motor control",
                        "Need a silent or tactile way to communicate"
                    ])
                }

                MorseSectionCard(title: "Reference Chart", systemImage: "doc.richtext") {
                    Text("Below is a chart showing the Morse code for letters A–Z and numbers 0–9.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MorseChartCard(title: "Morse Letters and Numbers", assetName: "Morse_Chart")
                }
            }
            .padding()
        }
        .navigationTitle("Morse Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MorseHeroCard: View {
    @Environment(\.appThemeColor) private var appThemeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(appThemeColor))
                VStack(alignment: .leading, spacing: 4) {
                    Text("How Morse Code Works")
                        .font(.title2.bold())
                    Text("Communicate using short and long signals called dots and dashes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                MorseSignalCard(symbol: "·", label: "Dot", detail: "Short tap or vibration")
                MorseSignalCard(symbol: "–", label: "Dash", detail: "Longer tap or vibration")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [appThemeColor.opacity(0.12), appThemeColor.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(appThemeColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct MorseSignalCard: View {
    let symbol: String
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(symbol)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
            Text(label)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct MorseSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
            }
            content
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

private struct MorseBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.body.weight(.semibold))
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MorseExampleBlock: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                if line.isEmpty {
                    Spacer().frame(height: 4)
                } else {
                    Text(line)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct MorseChartCard: View {
    let title: String
    let assetName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("\(title) Morse chart")
                    .overlay(
                        Group {
                            if UIImage(named: assetName) == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.08))
                                    VStack(spacing: 8) {
                                        Image(systemName: "doc.richtext")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.secondary)
                                        Text("Add image named \"\(assetName)\"")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
