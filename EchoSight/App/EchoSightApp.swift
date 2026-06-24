// MARK: - File Guide
// This is the true app entry point. SwiftUI starts here, then RootView
// decides whether to show loading, onboarding, or the main home screen.

//
//  EchoSightApp.swift
//  EchoSight
//
//  Created by Ram Verma on 1/28/26.
//

import SwiftUI

// App entry point.
// SwiftUI starts here, then hands control to RootView in Features/Onboarding.
// RootView decides whether the user sees loading, onboarding, or the main app.
@main
struct EchoSightApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
