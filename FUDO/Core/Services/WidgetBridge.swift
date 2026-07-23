import Foundation
import WidgetKit

/// APP-SIDE writer of the widget bridge (model P7). Builds a `WidgetSnapshot`
/// from the live `GameStore` and pushes it into the App Group, then reloads the
/// widget timelines. Called from the store's single mutation path
/// (`GameStore.save()`), so every check / uncheck / rollover / challenge
/// start-end / rule edit / erase keeps the widget honest with zero extra call
/// sites. The widget target never sees this type — it reads the snapshot only.
enum WidgetBridge {

    /// Rebuilds the snapshot and reloads timelines iff the stored blob changed.
    /// No player == erased/onboarding-not-started → clear the snapshot so the
    /// widget shows its empty state.
    @MainActor
    static func refresh(from store: GameStore) {
        let changed: Bool
        if let snapshot = buildSnapshot(from: store) {
            changed = snapshot.save()
        } else {
            changed = WidgetSnapshot.clear()
        }
        if changed { WidgetCenter.shared.reloadAllTimelines() }
    }

    @MainActor
    private static func buildSnapshot(from store: GameStore) -> WidgetSnapshot? {
        guard let player = store.player else { return nil }
        let ovr = OVREngine.displayedOVR(player.ovrValue)
        let rankName = player.rank.displayName

        guard let challenge = store.activeChallenge else {
            // Retention state: rank + OVR, no challenge.
            return WidgetSnapshot(ovr: ovr, rankName: rankName, streak: player.currentStreak,
                                  dayIndex: 0, totalDays: 0, remainingTasks: [],
                                  remainingCount: 0, hasActiveChallenge: false)
        }

        let log = store.currentLog()
        let unchecked = challenge.activeRules.filter { !(log?.isChecked($0) ?? false) }
        let tasks = unchecked.prefix(3).map { WidgetTask(title: $0.title, icon: $0.iconName) }
        return WidgetSnapshot(ovr: ovr, rankName: rankName, streak: player.currentStreak,
                              dayIndex: store.todayNumber ?? 0, totalDays: challenge.durationDays,
                              remainingTasks: Array(tasks), remainingCount: unchecked.count,
                              hasActiveChallenge: true)
    }

    // MARK: - Analytics: widget_detected (§ANALYTICS-PLAN)

    private static let lastSeenFamiliesKey = "widget.lastSeenFamilies"

    /// Fires `widget_detected` from the APP on foreground, only when the set of
    /// installed widget families changes (persisted in standard UserDefaults).
    /// DEBUG is a no-op through the `Analytics` facade — zero capture.
    static func reportInstalledWidgetsIfChanged() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            guard case .success(let widgets) = result else { return }
            let families = Set(widgets.map { familyName($0.family) }).sorted()
            let defaults = UserDefaults.standard
            let last = defaults.stringArray(forKey: lastSeenFamiliesKey) ?? []
            guard families != last else { return }
            defaults.set(families, forKey: lastSeenFamiliesKey)
            Analytics.track(AnalyticsEvent.widgetDetected, ["families": families])
        }
    }

    /// Stable, bracketed labels — the network never sees raw enum internals.
    private static func familyName(_ family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: return "small"
        case .systemMedium: return "medium"
        case .systemLarge: return "large"
        case .systemExtraLarge: return "extra_large"
        default: return "other"
        }
    }
}
