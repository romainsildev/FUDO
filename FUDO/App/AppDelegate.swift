import UIKit
import UserNotifications

/// Minimal UIKit adaptor for the ONE thing SwiftUI can't own: the notification
/// delegate. Registered via `@UIApplicationDelegateAdaptor` in `FUDOApp`.
///
/// On tap it fires `notification_tapped {id}` (analytics facade), THEN routes the
/// deep link into `NotificationRouter` for `RootView` to present. No game logic,
/// no persistence here — it hands off and returns.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Foreground delivery: show nothing. The app itself is the surface — a
    /// rank-up plays its cover, a nudge is moot while he's already inside.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    /// A tap. Report it (before routing), then route.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo

        if let id = info[NotificationCopy.idKey] as? String {
            Analytics.track(AnalyticsEvent.notificationTapped, ["id": id])
        }

        // Deep link → rank-up share card. The rank travels as a raw Int in userInfo.
        if let link = info[NotificationCopy.deepLinkKey] as? String,
           link == NotificationCopy.rankUpShareLink,
           let rankRaw = info[NotificationCopy.rankRawKey] as? Int,
           let rank = Rank(rawValue: rankRaw) {
            Task { @MainActor in
                NotificationRouter.shared.pendingDeepLink = .rankUpShare(rank: rank)
            }
        }

        completionHandler()
    }
}
