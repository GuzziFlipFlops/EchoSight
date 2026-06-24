// MARK: - File Guide
// Central alert/haptic/watch bridge. Features call this when something
// important happens, instead of duplicating alert logic everywhere.

import Foundation
import UIKit
import WatchConnectivity

enum AssistAlertKind: String {
    // Types are sent to Apple Watch so it can choose haptic style.
    case morse
    case obstacle
    case sound
    case practice
}

// Sends local haptics on iPhone and relays alert messages to Apple Watch
// when a companion watch app is available.
final class AssistAlertCenter: NSObject, WCSessionDelegate {
    // Shared alert center used by camera, mic, Morse, and practice features.
    static let shared = AssistAlertCenter()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            // Activate WatchConnectivity only when supported.
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func alert(_ kind: AssistAlertKind, message: String) {
        // Always provide immediate phone haptic feedback.
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(kind == .obstacle ? .warning : .success)

        // Watch relay is optional and only runs when a companion watch app exists.
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else {
            return
        }

        // transferUserInfo queues delivery even if the watch is not immediately reachable.
        WCSession.default.transferUserInfo([
            "kind": kind.rawValue,
            "message": message,
            "date": Date().timeIntervalSince1970
        ])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Required by WatchConnectivity after deactivation.
        session.activate()
    }
}
