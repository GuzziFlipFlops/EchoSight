// MARK: - File Guide
// ASL learning screens. Shows alphabet cards, number cards, phrase lessons,
// and tip cards backed by bundled image assets.

import SwiftUI

// Updated ASLAlphabetPage with added "ASL Numbers" tile
// ASL hub: alphabet, numbers, phrases, and practice.
struct ASLAlphabetPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TileLink(title: "ASL Tips", subtitle: "Get helpful guidance", systemImage: "lightbulb.fill", destination: AnyView(ASLTutorialPage()))
                TileLink(title: "ASL Alphabet", subtitle: "Browse letters A–Z", systemImage: "hand.raised.fill", destination: AnyView(ASLAlphabetLearnView()))
                TileLink(title: "ASL Numbers", subtitle: "Numbers 1–20", systemImage: "123.rectangle", destination: AnyView(ASLNumbersLearnView()))
                TileLink(title: "ASL Phrases", subtitle: "Practice common phrases", systemImage: "text.bubble", destination: AnyView(ASLPhrasesPage()))
                TileLink(title: "Daily Practice", subtitle: "Streaks, quizzes, and progress", systemImage: "target", destination: AnyView(PracticeHubPage()))
            }
            .padding()
        }
        .navigationTitle("ASL")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ASL Alphabet Learn (A–Z with slider + scroll)
struct ASLAlphabetLearnView: View {
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

                // Slider to quickly jump between letters A..Z
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

                // Scrollable list of letters with images
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(0..<letters.count, id: \.self) { letterIndex in
                            ASLLetterCard(letter: letters[letterIndex], index: letterIndex)
                                .id(letterIndex)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: LetterOffsetKey.self,
                                            value: [letterIndex: geo.frame(in: .named("scroll")).minY]
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
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(LetterOffsetKey.self) { offsets in
                    guard !offsets.isEmpty else { return }
                    if isDraggingSlider { return }
                    // Pick the item whose top is closest to a small inset from the top (e.g., 20 pts)
                    let targetTop: CGFloat = 20
                    let closest = offsets.min(by: { abs($0.value - targetTop) < abs($1.value - targetTop) })
                    if let closestLetterIndex = closest?.key, closestLetterIndex != selectedIndex {
                        selectedIndex = closestLetterIndex
                    }
                }
            }
        }
        .navigationTitle("ASL Alphabet")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// Tracks each letter card's vertical position in the ScrollView
private struct LetterOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// Single letter card showing the letter and its image (placeholder if missing)
private struct ASLLetterCard: View {
    let letter: String
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                // Primary image (expects assets named ASL_A, ASL_B, ..., ASL_Z)
                Image("ASL_\(letter)")
                    .resizable()
                    .aspectRatio(CGSize(width: 255, height: 285), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("ASL sign for letter \(letter)")
                    .overlay(
                        Group {
                            // If the asset doesn't exist yet, show a helpful placeholder
                            if UIImage(named: "ASL_\(letter)") == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.08))
                                    VStack(spacing: 8) {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.secondary)
                                        Text("Add image named \"ASL_\(letter)\"")
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

// MARK: - ASL Phrases (placeholder)
// Phrase library that breaks common ASL phrases into learnable word tiles.
struct ASLPhrasesPage: View {
    private let sections: [(title: String, items: [String])] = [
        (
            title: "Greetings",
            items: [
                "Hello",
                "Nice to meet you",
                "Good morning",
                "Goodbye"
            ]
        ),
        (
            title: "Basic Questions",
            items: [
                "What is your name?",
                "How are you?",
                "Where is the bathroom?",
                "Can you help me?"
            ]
        ),
        (
            title: "Common Responses",
            items: [
                "Yes",
                "No",
                "Please",
                "Thank you"
            ]
        ),
        (
            title: "Conversation Help",
            items: [
                "I don't understand",
                "Can you repeat that?",
                "Slow down please",
                "One moment"
            ]
        ),
        (
            title: "Introductions",
            items: [
                "My name is ___",
                "I am learning ASL",
                "I'm sorry",
                "Thank you for your patience"
            ]
        ),
        (
            title: "Polite / Everyday Use",
            items: [
                "Excuse me",
                "That's okay",
                "No problem",
                "I appreciate it"
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<sections.count, id: \.self) { i in
                    PhraseSection(title: sections[i].title, items: sections[i].items)
                }
            }
            .padding()
        }
        .navigationTitle("ASL Phrases")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct PhraseSection: View {
    @AppStorage("accessibility.simplifiedUI") private var simplifiedUI: Bool = false
    @Environment(\.appThemeColor) private var appThemeColor

    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(simplifiedUI ? .system(size: 28, weight: .bold) : .headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(simplifiedUI ? 18 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(simplifiedUI ? appThemeColor : appThemeColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(appThemeColor.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundStyle(simplifiedUI ? .white : .primary)

            ForEach(items, id: \.self) { item in
                NavigationLink {
                    PhraseDetailPage(phrase: item)
                } label: {
                    HStack(spacing: 12) {
                        Text(item)
                            .font(simplifiedUI ? .system(size: 22, weight: .semibold) : .subheadline)
                            .foregroundStyle(simplifiedUI ? .white : .primary)
                        Spacer()
                        Text("->")
                            .font((simplifiedUI ? .system(size: 22, weight: .bold) : .subheadline.weight(.semibold)))
                            .foregroundStyle(simplifiedUI ? .white.opacity(0.9) : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(simplifiedUI ? 18 : 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(simplifiedUI ? appThemeColor.opacity(0.9) : Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.secondary.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PhraseDetailPage: View {
    @AppStorage("accessibility.simplifiedUI") private var simplifiedUI: Bool = false

    let phrase: String
    private var words: [String] {
        let separators = CharacterSet.whitespacesAndNewlines
        return phrase
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: CharacterSet.letters.inverted) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    PhraseWordTile(word: word)
                }
            }
            .padding()
        }
        .navigationTitle(phrase)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct PhraseWordTile: View {
    @AppStorage("accessibility.simplifiedUI") private var simplifiedUI: Bool = false
    @Environment(\.appThemeColor) private var appThemeColor

    let word: String

    private var letters: [Character] {
        word.compactMap { char in
            char.isLetter ? char : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(word)
                .font(simplifiedUI ? .system(size: 26, weight: .bold) : .headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if letters.isEmpty {
                        Text("No letters to display.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                            ASLPhraseLetterCard(letter: letter)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(simplifiedUI ? 18 : 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(simplifiedUI ? appThemeColor.opacity(0.12) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.secondary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct ASLPhraseLetterCard: View {
    let letter: Character

    private var assetName: String {
        "ASL_\(String(letter).uppercased())"
    }

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .aspectRatio(CGSize(width: 255, height: 285), contentMode: .fit)
                .frame(width: 140, height: 190)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                )
                .accessibilityLabel("ASL letter \(letter)")
                .overlay(
                    Group {
                        if UIImage(named: assetName) == nil {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.08))
                                VStack(spacing: 6) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                    Text("Add \(assetName)")
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
}

// MARK: - ASL Numbers (1–20 with slider + scroll)
struct ASLNumbersLearnView: View {
    @State private var selectedIndex: Int = 0
    @State private var isDraggingSlider: Bool = false
    @State private var pendingScroll: DispatchWorkItem?
    private let numbers: [Int] = Array(1...20)
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

                // Slider to quickly jump between numbers 1..20
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

                // Scrollable list of numbers with images
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(0..<numbers.count, id: \.self) { numberIndex in
                            ASLNumberCard(number: numbers[numberIndex], index: numberIndex)
                                .id(numberIndex)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: NumberOffsetKey.self,
                                            value: [numberIndex: geo.frame(in: .named("numbersScroll")).minY]
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
                .coordinateSpace(name: "numbersScroll")
                .onPreferenceChange(NumberOffsetKey.self) { offsets in
                    guard !offsets.isEmpty else { return }
                    if isDraggingSlider { return }
                    // Pick the item whose top is closest to a small inset from the top (e.g., 20 pts)
                    let targetTop: CGFloat = 20
                    let closest = offsets.min(by: { abs($0.value - targetTop) < abs($1.value - targetTop) })
                    if let closestNumberIndex = closest?.key, closestNumberIndex != selectedIndex {
                        selectedIndex = closestNumberIndex
                    }
                }
            }
        }
        .navigationTitle("ASL Numbers")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// Tracks each number card's vertical position in the ScrollView
private struct NumberOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// Single number card showing the number's image (placeholder if missing)
private struct ASLNumberCard: View {
    let number: Int
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                // Primary image (expects assets named ASL_1, ASL_2, ..., ASL_20)
                Image("ASL_\(number)")
                    .resizable()
                    .aspectRatio(CGSize(width: 237, height: 406), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("ASL sign for number \(number)")
                    .overlay(
                        Group {
                            // If the asset doesn't exist yet, show a helpful placeholder
                            if UIImage(named: "ASL_\(number)") == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.08))
                                    VStack(spacing: 8) {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.secondary)
                                        Text("Add image named \"ASL_\(number)\"")
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

// Shared ASL tip card used by both the ASL pages and tutorial pages.
struct InfoTile: View {
    @AppStorage("accessibility.simplifiedUI") private var simplifiedUI: Bool = false
    @Environment(\.appThemeColor) private var appThemeColor

    let title: String
    let text: String

    var body: some View {
        Group {
            if simplifiedUI {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(text)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appThemeColor)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.secondary.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}

#Preview {
    HomeView()
}
