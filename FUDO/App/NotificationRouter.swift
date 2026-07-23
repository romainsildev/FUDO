import Observation

/// A deep link carried in from a tapped notification. Only rank-up routes anywhere
/// today (→ the share card); the enum exists so new links are additive.
enum FudoDeepLink: Equatable {
    /// Tapping the rank-up notification opens the share card for the crossed rank.
    case rankUpShare(rank: Rank)
}

/// The single hand-off between the `UNUserNotificationCenter` delegate (UIKit world,
/// no SwiftUI environment) and `RootView` (which owns presentation). The delegate
/// writes `pendingDeepLink`; RootView drains it and clears it. A shared singleton
/// because the delegate is created by UIKit, outside the view environment.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()
    var pendingDeepLink: FudoDeepLink?
    private init() {}
}
