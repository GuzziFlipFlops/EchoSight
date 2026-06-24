// MARK: - File Guide
// Practice dashboard UI. Shows lesson streaks, completed lessons,
// achievements, and quick actions for ASL and Morse learning.

import SwiftUI

// Lightweight practice tracker for ASL and Morse daily progress.
struct PracticeHubPage: View {
    // PracticeStore persists streaks and lesson counts across launches.
    @StateObject private var practice = PracticeStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PracticeSummaryCard(practice: practice)
                ForEach(PracticeTrack.allCases) { track in
                    PracticeTrackCard(track: track, progress: practice.progress(for: track)) {
                        practice.completeDailyLesson(track: track)
                    }
                }
                OfflinePrivacyCard()
            }
            .padding()
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .background(EchoSightBackground())
    }
}

private struct PracticeSummaryCard: View {
    // ObservedObject is used because PracticeHubPage owns the store lifetime.
    @ObservedObject var practice: PracticeStore

    var body: some View {
        HStack(spacing: 12) {
            DashboardStatusCard(title: "Lessons", detail: "\(practice.totalCompletedLessons) complete", systemImage: "checkmark.seal.fill", tint: .green)
            DashboardStatusCard(title: "Best Streak", detail: "\(practice.bestStreak) days", systemImage: "flame.fill", tint: .orange)
        }
    }
}

private struct PracticeTrackCard: View {
    // Each card is intentionally data-driven so ASL and Morse share one layout.
    let track: PracticeTrack
    let progress: PracticeProgress
    let complete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: track.systemImage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(track.title) Daily Lesson")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(nextLesson)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                PracticeMiniMetricCard(value: "\(progress.completedLessons)", label: "lessons", systemImage: "checkmark")
                PracticeMiniMetricCard(value: "\(progress.streak)", label: "streak", systemImage: "flame.fill")
                PracticeMiniMetricCard(value: "\(progress.achievements.count)", label: "badges", systemImage: "rosette")
            }

            Button {
                complete()
            } label: {
                Label("Complete today's lesson", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableButtonStyle(prominent: true))

            if !progress.achievements.isEmpty {
                Text("Achievements: \(progress.achievements.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var nextLesson: String {
        // Simple lesson copy for now; the progress store handles completion.
        switch track {
        case .asl:
            return "Practice 5 signs, then review one phrase."
        case .morse:
            return "Practice 5 letters, then play one word."
        }
    }
}

private struct PracticeMiniMetricCard: View {
    // Reusable compact metric used inside practice cards.
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.heavy))
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
