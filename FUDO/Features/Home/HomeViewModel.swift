import Foundation
import Observation

/// Home screen state — never an empty screen (CLAUDE.md).
enum HomeScreenState: Equatable {
    case noChallenge   // frame 01b — persistent rank, CTA to start again
    case inProgress    // frame 01 — the day is being played
    case dayComplete   // frame 01c — 100 % checked, sealed ring
}

/// One checklist row: rule + today's checked state, in display order.
struct HomeChecklistItem: Identifiable, Equatable {
    let rule: TaskRule
    let isChecked: Bool
    var id: UUID { rule.id }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.isChecked == rhs.isChecked
    }
}

/// What the rollover just took — feeds the factual banner ("Yesterday: incomplete.
/// OVR -4."). `dayCount` > 1 when the app stayed closed across several missed days.
struct IncompleteRolloverSummary: Equatable {
    let dayCount: Int
    /// Summed penalties of the trailing incomplete days (what the OVR lost at
    /// closure — live gains of those days were already on screen when earned).
    let ovrDrop: Double
}

/// One pastille of the flame-sheet week (Monday-first, per frame 09 — EN-only app,
/// fixed order regardless of locale).
struct FlameWeekDay: Identifiable {
    enum State {
        case done                // filled vermillon ✓
        case missed              // dead + struck through
        case today(Double)       // partial ring mirroring the day ring
        case upcoming            // empty outline
        case idle                // outside any challenge — dim, nothing scheduled
    }
    let id: Int
    let letter: String
    let isToday: Bool
    let state: State
}

/// Home = pure derivation over GameStore (the single mutation path). Zero game math
/// here — every number comes from the models via the store / OVREngine. Owns only
/// UI state: presented sheet/cover and the sensei reaction triggers. Triggers start
/// at 0 on every launch, so a killed-then-relaunched app never replays a celebration
/// (known-pitfalls list).
@MainActor
@Observable
final class HomeViewModel {
    private let store: GameStore

    var presentedSheet: FudoSheet?
    var presentedCover: FudoCover?

    /// Increments on every successful check — SenseiStageView listens and pulses.
    private(set) var checkPulseTrigger = 0
    /// Increments only when the day flips to 100 % LIVE under the user's finger.
    private(set) var celebrationTrigger = 0

    /// Effective day whose incomplete banner was dismissed — persisted so a
    /// killed-then-relaunched app never re-shows a banner the user already closed
    /// (known-pitfalls list). A new rollover day is a new banner.
    private var dismissedBannerDay: Date?
    private static let dismissedBannerDayKey = "home.incompleteBanner.dismissedDay"
    /// Fire just past the 2 AM boundary, never on it.
    private static let rolloverTimerSlack: TimeInterval = 1

    init(store: GameStore) {
        self.store = store
        self.dismissedBannerDay = UserDefaults.standard
            .object(forKey: Self.dismissedBannerDayKey) as? Date
    }

    // MARK: - Rollover (UI side — the engine owns the rules)

    /// Foreground clock: sleeps to the next grace boundary (2 AM) and rolls the day
    /// over LIVE while the app stays on screen. RootView's scene-active refresh
    /// covers every backgrounded crossing; `processRolloverIfNeeded` is idempotent,
    /// so the two paths double-firing is harmless. Attach via `.task` — cancellation
    /// follows the view's lifetime.
    func watchRolloverWhileForeground() async {
        while !Task.isCancelled {
            let seconds = store.timeUntilNextRollover + Self.rolloverTimerSlack
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            store.processRolloverIfNeeded()
        }
    }

    /// Trailing run of closed-incomplete days ending yesterday, with the summed
    /// penalties the closures took. Nil when yesterday was complete (or no data).
    var incompleteRollover: IncompleteRolloverSummary? {
        guard store.activeChallenge != nil else { return nil }
        let calendar = store.displayCalendar
        var day = calendar.date(byAdding: .day, value: -1, to: store.effectiveToday)
        var count = 0
        var drop = 0.0
        while let current = day, let log = store.dayLog(on: current),
              log.isClosed, !log.isComplete {
            count += 1
            drop += max(0, log.checksTotal - log.ovrDelta)   // ovrDelta = checks − penalty
            day = calendar.date(byAdding: .day, value: -1, to: current)
        }
        guard count > 0 else { return nil }
        return IncompleteRolloverSummary(dayCount: count, ovrDrop: drop)
    }

    var showsIncompleteBanner: Bool {
        guard incompleteRollover != nil else { return false }
        guard let dismissed = dismissedBannerDay else { return true }
        return !store.displayCalendar.isDate(dismissed, inSameDayAs: store.effectiveToday)
    }

    func dismissIncompleteBanner() {
        dismissedBannerDay = store.effectiveToday
        UserDefaults.standard.set(store.effectiveToday, forKey: Self.dismissedBannerDayKey)
    }

    // MARK: - Screen state

    var screenState: HomeScreenState {
        guard store.activeChallenge != nil else { return .noChallenge }
        return isDayComplete ? .dayComplete : .inProgress
    }

    var isDayComplete: Bool { totalCount > 0 && checkedCount == totalCount }

    // MARK: - Header

    var rank: Rank { store.player?.rank ?? .novice }

    /// "DAY 12 / 30" while a challenge runs; brand mark otherwise (frame 01b).
    var dayPillLabel: String {
        guard let challenge = store.activeChallenge, let day = store.todayNumber else { return "FUDO" }
        return "DAY \(day) / \(challenge.durationDays)"
    }

    var streak: Int { store.player?.currentStreak ?? 0 }

    /// Greyed flame pill when there is nothing burning (streak 0 or no challenge).
    var streakIsAlive: Bool { streak > 0 && store.activeChallenge != nil }

    // MARK: - OVR block

    var displayedOVR: Int { store.player?.displayedOVR ?? 0 }

    /// Micro-badge next to the OVR. Priority: today's live gains; failing that, the
    /// penalty the morning rollover just applied for an incomplete yesterday — the
    /// SAME metric the banner shows (yesterday's live gains were on screen when
    /// earned, so the morning drop is the penalty alone, not the day's net).
    var ovrDeltaToday: Double? {
        if let log = store.currentLog(), log.checksTotal > 0 { return log.checksTotal }
        if store.activeChallenge != nil,
           let yesterday = yesterdayLog, yesterday.isClosed, !yesterday.isComplete {
            let penalty = max(0, yesterday.checksTotal - yesterday.ovrDelta)
            return penalty > 0 ? -penalty : nil
        }
        return nil
    }

    /// Drives the slumped sensei posture (Duolingo pattern — the sensei carries the shame).
    var isYesterdayIncomplete: Bool {
        guard store.activeChallenge != nil, let log = yesterdayLog else { return false }
        return log.isClosed && !log.isComplete
    }

    private var yesterdayLog: DayLog? {
        guard let yesterday = store.displayCalendar.date(byAdding: .day, value: -1,
                                                         to: store.effectiveToday) else { return nil }
        return store.dayLog(on: yesterday)
    }

    /// Frame 01c — factual, dur-mais-satisfait.
    var completionMessage: String {
        guard let day = store.todayNumber else { return "Day complete. Return tomorrow." }
        return "Day \(day): complete. Return tomorrow."
    }

    // MARK: - Checklist

    /// Unchecked first (rule order), checked slide to the bottom (rule order).
    var items: [HomeChecklistItem] {
        guard let challenge = store.activeChallenge else { return [] }
        let log = store.currentLog()
        let all = challenge.activeRules.map {
            HomeChecklistItem(rule: $0, isChecked: log?.isChecked($0) ?? false)
        }
        return all.filter { !$0.isChecked } + all.filter(\.isChecked)
    }

    var checkedCount: Int { items.filter(\.isChecked).count }
    var totalCount: Int { items.count }
    var dayProgress: Double { totalCount > 0 ? Double(checkedCount) / Double(totalCount) : 0 }

    /// Called by the row when the hold-to-check completes (HoldToConfirm guarantees
    /// exactly one call and already fired the success haptic). Returns the exact OVR
    /// delta the engine granted — the row floats it as "+X OVR" — or nil if the
    /// store refused the check (closed day…).
    func confirmCheck(_ item: HomeChecklistItem) -> Double? {
        guard !item.isChecked else { return nil }
        let wasComplete = isDayComplete
        store.checkTask(item.rule)
        guard let granted = store.currentLog()?.checks
            .first(where: { $0.ruleID == item.rule.id })?.ovrDelta else { return nil }
        checkPulseTrigger += 1
        if !wasComplete && isDayComplete {
            celebrationTrigger += 1
        }
        return granted
    }

    /// Confirmed through the row's dialog — exact refund, no burst, no celebration.
    func uncheck(_ item: HomeChecklistItem) {
        guard item.isChecked else { return }
        store.uncheckTask(item.rule)
    }

    // MARK: - Flame sheet (aggregated from DayLog — no new data)

    var bestStreak: Int { store.player?.bestStreak ?? 0 }
    var totalChecksAllTime: Int { store.totalChecksAllTime }

    var flameWeek: [FlameWeekDay] {
        let calendar = store.displayCalendar
        let today = store.effectiveToday
        // Monday of the current week: Calendar.weekday is 1 = Sunday … 7 = Saturday.
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday,
                                         to: today) else { return [] }
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: monday) else { return nil }
            let state: FlameWeekDay.State
            if calendar.isDate(day, inSameDayAs: today) {
                state = store.activeChallenge != nil ? .today(dayProgress) : .idle
            } else if day > today {
                state = .upcoming
            } else if let log = store.dayLog(on: day) {
                state = log.isComplete ? .done : .missed
            } else {
                state = .idle
            }
            return FlameWeekDay(id: index, letter: letters[index],
                                isToday: calendar.isDate(day, inSameDayAs: today), state: state)
        }
    }
}

extension Rank {
    /// UPPERCASE display name — Home OVR block and no-challenge state.
    var displayName: String {
        switch self {
        case .novice:   return "NOVICE"
        case .disciple: return "DISCIPLE"
        case .ascetic:  return "ASCETIC"
        case .warrior:  return "WARRIOR"
        case .master:   return "MASTER"
        case .sensei:   return "SENSEI"
        }
    }
}
