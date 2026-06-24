// MARK: - File Guide
// Entry page for microphone tools. It gives users a simple path into live
// captions, sound awareness, and the microphone visualizer.

import SwiftUI

// Mic feature entry point. Detailed mic logic lives in Features/Mic/AudioPipeline.
struct MicPage: View {
    // StateObject means the mic session/view model stays alive while this page is open.
    @StateObject private var viewModel = MicViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MicTileView(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("Mic")
        .navigationBarTitleDisplayMode(.inline)
    }
}
