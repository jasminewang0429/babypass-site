import SwiftUI
import Combine
import UIKit
import UserNotifications
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging

/// Owns iOS push notification permission state and FCM token registration.
/// Wired in from AuthService (sign-in / sign-out) and from AppDelegate
/// (MessagingDelegate forwards new tokens here).
final class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()

    @Published var permissionDenied: Bool = false

    private let db = Firestore.firestore()
    private var latestToken: String?

    private init() {}

    /// Called on sign-in. Requests notification permission if not yet
    /// determined, then triggers APNs registration. Safe to call repeatedly.
    func registerIfNeeded(uid: String) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        self?.permissionDenied = !granted
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    self?.permissionDenied = true
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    self?.permissionDenied = false
                    UIApplication.shared.registerForRemoteNotifications()
                    // MessagingDelegate's didReceiveRegistrationToken only
                    // fires once per launch (before sign-in, when currentUser
                    // is nil), so on sign-in we must refetch and write the
                    // current token ourselves.
                    Messaging.messaging().token { [weak self] token, error in
                        if let error = error {
                            print("PushNotificationService.registerIfNeeded fetch token failed: \(error)")
                            return
                        }
                        guard let token = token else { return }
                        self?.handleNewToken(token)
                    }
                }
            @unknown default:
                break
            }
        }
    }

    /// Called by AppDelegate's MessagingDelegate when FCM hands us a fresh
    /// registration token. Writes (or refreshes) the token under
    /// `users/{currentUid}/fcmTokens/{deviceId}`.
    func handleNewToken(_ token: String) {
        latestToken = token
        guard let uid = Auth.auth().currentUser?.uid else { return }
        writeToken(token, for: uid)
    }

    /// Called BEFORE Auth.auth().signOut() (currentUser must still be set so
    /// we can target the right doc). Deletes the per-device token doc; does
    /// NOT call unregisterForRemoteNotifications — the user may sign back in.
    func unregister() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid)
            .collection("fcmTokens").document(Self.deviceId).delete()
    }

    private func writeToken(_ token: String, for uid: String) {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let doc: [String: Any] = [
            "token": token,
            "platform": "ios",
            "lastSeen": Timestamp(date: Date()),
            "appBuild": build
        ]
        db.collection("users").document(uid)
            .collection("fcmTokens").document(Self.deviceId)
            .setData(doc, merge: true)
    }

    private static var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}
