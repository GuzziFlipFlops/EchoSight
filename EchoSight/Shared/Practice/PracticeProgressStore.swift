// MARK: - File Guide
// Local progress database for ASL and Morse practice. Tracks streaks,
// completed lessons, achievements, and last practice date.

import Combine
import Foundation

enum PracticeTrack: String, Codable, CaseIterable, Identifiable {
    // Practice currently tracks ASL and Morse separately.
    case asl
    case morse

    var id: String { rawValue }

    var title: String {
        // Display title for cards and history entries.
        switch self {
        case .asl: return "ASL"
        case .morse: return "Morse"
        }
    }

    var systemImage: String {
        switch self {
        case .asl: return "hand.raised.fill"
        case .morse: return "dot.radiowaves.left.and.right"
        }
    }
}

struct PracticeProgress: Codable, Equatable {
    // Stored progress for one practice track.
    var track: PracticeTrack
    var streak: Int = 0
    var completedLessons: Int = 0
    var achievements: [String] = []
    var lastPracticeDate: Date?
}

@MainActor
// Tracks daily progress for ASL and Morse practice.
final class PracticeStore: ObservableObject {
    // Shared store so PracticeHub and feature screens see the same progress.
    static let shared = PracticeStore()

    // Dictionary keyed by track for fast lookup.
    @Published private(set) var progress: [PracticeTrack: PracticeProgress] = [:]
    private let defaultsKey = "practice.progress"

    private init() {
        load()
    }

    func progress(for track: PracticeTrack) -> PracticeProgress {
        // If the track has no saved data yet, return a fresh zero-progress item.
        progress[track] ?? PracticeProgress(track: track)
    }

    var totalCompletedLessons: Int {
        // Sum across all tracks for dashboard metric.
        progress.values.reduce(0) { $0 + $1.completedLessons }
    }

    var bestStreak: Int {
        // Highest streak across all tracks.
        progress.values.map(\.streak).max() ?? 0
    }

    func completeDailyLesson(track: PracticeTrack) {
        // Count at most one lesson per track per day for streak integrity.
        var item = progress(for: track)
        let calendar = Calendar.current
        let now = Date()

        if let last = item.lastPracticeDate {
            if calendar.isDateInToday(last) {
                // Already counted today, so only log a reminder.
                ActivityHistoryStore.shared.add(.practice, title: "\(track.title) practiced", detail: "Daily lesson already counted today.")
                return
            } else if calendar.isDateInYesterday(last) {
                // Consecutive day continues streak.
                item.streak += 1
            } else {
                // Gap resets streak.
                item.streak = 1
            }
        } else {
            // First ever practice starts a streak.
            item.streak = 1
        }

        // Update persisted progress.
        item.completedLessons += 1
        item.lastPracticeDate = now
        item.achievements = achievements(for: item)
        progress[track] = item
        save()

        // Log locally and trigger haptic/watch alert.
        ActivityHistoryStore.shared.add(.practice, title: "\(track.title) lesson", detail: "Completed lesson \(item.completedLessons). Streak: \(item.streak) day\(item.streak == 1 ? "" : "s").")
        AssistAlertCenter.shared.alert(.practice, message: "\(track.title) practice complete")
    }

    private func achievements(for progress: PracticeProgress) -> [String] {
        // Badge list is derived from progress instead of stored manually.
        var achievements: [String] = []
        if progress.completedLessons >= 1 { achievements.append("First lesson") }
        if progress.completedLessons >= 5 { achievements.append("Five lessons") }
        if progress.streak >= 3 { achievements.append("Three-day streak") }
        if progress.streak >= 7 { achievements.append("Weekly streak") }
        return achievements
    }

    private func load() {
        // Load saved progress or initialize both tracks.
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([PracticeTrack: PracticeProgress].self, from: data) else {
            progress = Dictionary(uniqueKeysWithValues: PracticeTrack.allCases.map { ($0, PracticeProgress(track: $0)) })
            return
        }
        progress = decoded
    }

    private func save() {
        // Persist progress locally as JSON.
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
