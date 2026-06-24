// MARK: - File Guide
// UI for recent activity. It reads from ActivityHistoryStore and lets users
// review detections, transcripts, OCR text, Morse, ASL, and practice events.

import SwiftUI

// Shows the recent log of detections, captions, read text, practice, and alerts.
struct ActivityHistoryPage: View {
    // Shared singleton means any tool can log activity without passing bindings.
    @StateObject private var history = ActivityHistoryStore.shared

    var body: some View {
        List {
            Section {
                if history.items.isEmpty {
                    // Empty state keeps the page useful before the user has run
                    // any camera, mic, Morse, ASL, or practice actions.
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "clock",
                        description: Text("Detections, captions, read text, Morse, ASL, and practice sessions will appear here.")
                    )
                } else {
                    // Newest items are already first because ActivityHistoryStore
                    // inserts at the front.
                    ForEach(history.items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.kind.systemImage)
                                .font(.headline)
                                .foregroundStyle(.tint)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.accentColor.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    Spacer()
                                    Text(item.date, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Recent Activity")
            }
        }
        .navigationTitle("Activity History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !history.items.isEmpty {
                Button("Clear") {
                    history.clear()
                }
            }
        }
    }
}
