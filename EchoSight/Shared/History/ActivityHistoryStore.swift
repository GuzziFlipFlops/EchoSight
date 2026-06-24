// MARK: - File Guide
// Local activity database for the app. It saves recent events as JSON in
// UserDefaults and exposes them to history/dashboard screens.

import Combine
import Foundation

// ActivityHistoryStore.swift holds the local activity log.
// Keeping this shared lets any screen log events without knowing the current UI.
enum ActivityKind: String, Codable, CaseIterable {
    // Categories used by ActivityHistoryPage.
    case object
    case transcript
    case readText
    case morse
    case asl
    case practice
    case sound
    case system

    var title: String {
        // Human-readable section/title label.
        switch self {
        case .object: return "Object"
        case .transcript: return "Transcript"
        case .readText: return "Read Text"
        case .morse: return "Morse"
        case .asl: return "ASL"
        case .practice: return "Practice"
        case .sound: return "Sound"
        case .system: return "System"
        }
    }

    var systemImage: String {
        // SF Symbols icon shown beside each activity item.
        switch self {
        case .object: return "viewfinder"
        case .transcript: return "captions.bubble.fill"
        case .readText: return "doc.text.viewfinder"
        case .morse: return "antenna.radiowaves.left.and.right"
        case .asl: return "hand.raised.fill"
        case .practice: return "target"
        case .sound: return "waveform"
        case .system: return "checkmark.seal.fill"
        }
    }
}

struct ActivityItem: Identifiable, Codable, Equatable {
    // Codable lets the local history save to UserDefaults as JSON.
    var id = UUID()
    var kind: ActivityKind
    var title: String
    var detail: String
    var date = Date()
}

@MainActor
// Persistent event log for detections, captions, read text, Morse, ASL,
// practice, and system actions. Saves are debounced to keep the UI smooth.
final class ActivityHistoryStore: ObservableObject {
    // Singleton is convenient because every feature can log activity.
    static let shared = ActivityHistoryStore()

    // private(set) means views can read items, but only the store mutates them.
    @Published private(set) var items: [ActivityItem] = []
    // UserDefaults key for JSON encoded activity history.
    private let defaultsKey = "activity.history.items"
    // Limit keeps local storage and list rendering small.
    private let maxItems = 80
    // Debounce avoids writing UserDefaults on every rapid detection frame.
    private let saveDebounce: TimeInterval = 0.8
    private var pendingSave: DispatchWorkItem?

    private init() {
        load()
    }

    func add(_ kind: ActivityKind, title: String, detail: String) {
        // Empty entries are ignored so history stays meaningful.
        let cleanedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedDetail.isEmpty else { return }

        // Drop duplicates that happen within 10 seconds.
        if let latest = items.first,
           latest.kind == kind,
           latest.title == title,
           latest.detail == cleanedDetail,
           Date().timeIntervalSince(latest.date) < 10 {
            return
        }

        // Insert newest first for easier display.
        items.insert(ActivityItem(kind: kind, title: title, detail: cleanedDetail, date: Date()), at: 0)
        if items.count > maxItems {
            // Trim old items after maxItems.
            items = Array(items.prefix(maxItems))
        }
        scheduleSave()
    }

    func recent(limit: Int = 8) -> [ActivityItem] {
        // Helper for dashboard-style summaries.
        Array(items.prefix(limit))
    }

    func latest(kind: ActivityKind) -> ActivityItem? {
        // Find the most recent item of one category.
        items.first { $0.kind == kind }
    }

    func clear() {
        // Cancel pending delayed save, clear memory, then save empty array.
        pendingSave?.cancel()
        pendingSave = nil
        items = []
        save()
    }

    private func load() {
        // Load JSON from UserDefaults if it exists.
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ActivityItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        // Save as JSON data in UserDefaults. No network or database is involved.
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func scheduleSave() {
        // Keep only one pending save work item.
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.save()
            }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounce, execute: work)
    }
}
