import Foundation

/// The read-only bridge between the app and the widget (model P7). This file is
/// the ONE type shared by both targets — it is a member of the FUDO app target
/// (writes it) AND the FUDOWidgetExtension target (reads it), so there is a single
/// source of truth for the wire format. It imports Foundation only: the widget
/// must never touch SwiftData, RevenueCat or PostHog.
///
/// The app recomputes everything (OVR, rank name, day X/Y, remaining tasks) and
/// freezes it here; the widget only renders. Nothing is derived widget-side.

/// The App Group suite the app writes and the widget reads.
let fudoAppGroupID = "group.com.fudoapp.fudo"

/// One unchecked task shown in the medium widget's read-only checklist.
struct WidgetTask: Codable, Equatable {
    var title: String
    var icon: String   // SF Symbol name
}

/// Everything the widget needs to draw any state, in one flat value.
/// No snapshot stored at all == "app never opened" (the empty state).
struct WidgetSnapshot: Codable, Equatable {
    var ovr: Int                    // already floored via OVREngine.displayedOVR
    var rankName: String            // Rank.displayName (e.g. "Warrior")
    var streak: Int
    var dayIndex: Int               // "X" of day X / Y (0 when no active challenge)
    var totalDays: Int              // "Y" (0 when no active challenge)
    var remainingTasks: [WidgetTask]  // up to 3 unchecked active tasks of today
    var remainingCount: Int         // full count of unchecked active tasks (may exceed 3)
    var hasActiveChallenge: Bool
}

extension WidgetSnapshot {
    /// Versioned key: bumping it (v2…) lets a future format change invalidate the
    /// stale blob instead of mis-decoding it.
    static let defaultsKey = "widget.snapshot.v1"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: fudoAppGroupID)
    }

    /// Reads the current snapshot, or nil when none was ever written (empty state)
    /// or the App Group is unavailable (e.g. the unit-test host lacks the
    /// entitlement — a nil suite is handled, never a crash).
    static func load(from defaults: UserDefaults? = WidgetSnapshot.sharedDefaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Persists the snapshot. Returns `true` only when the stored bytes actually
    /// changed, so the caller can skip a redundant `reloadAllTimelines()`.
    /// JSON key order is deterministic (synthesized CodingKeys follow declaration
    /// order), so byte-equality is a safe change check.
    @discardableResult
    func save(to defaults: UserDefaults? = WidgetSnapshot.sharedDefaults) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return false }
        if let existing = defaults.data(forKey: Self.defaultsKey), existing == data { return false }
        defaults.set(data, forKey: Self.defaultsKey)
        return true
    }

    /// Removes any stored snapshot (data erased → widget falls back to empty
    /// state). Returns `true` when something was actually cleared.
    @discardableResult
    static func clear(from defaults: UserDefaults? = WidgetSnapshot.sharedDefaults) -> Bool {
        guard let defaults, defaults.data(forKey: defaultsKey) != nil else { return false }
        defaults.removeObject(forKey: defaultsKey)
        return true
    }
}
