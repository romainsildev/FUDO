import Foundation
import Observation

/// The ONE view model behind every challenge-setup skin (full flow, onboarding
/// inline, standalone cover) — preset/rule logic lives here, never in a view.
/// Selecting a preset reloads its default rules and DISCARDS edits (chip
/// semantics, decision 2026-07-12). An edited preset keeps its `preset` value:
/// `.custom` stays reserved for a future custom path.
@MainActor
@Observable
final class ChallengeSetupViewModel {
    static let defaultReminderMinutes = 7 * 60
    /// From the 7th enabled rule the UI shows "More rules = more failure."
    static let ruleCountWarningThreshold = 7

    let recommendedPreset: ChallengePreset
    private let store: GameStore
    /// Where a launch from this skin is attributed (`challenge_started.origin`).
    /// Home/onboarding default to `.home`; the post-challenge cover passes `.postChallenge`.
    private let origin: ChallengeOrigin

    private(set) var selectedPreset: ChallengePreset
    var rules: [EditableRule]
    var reminderMinutes: Int = ChallengeSetupViewModel.defaultReminderMinutes

    /// Did the user touch the rules since the last preset default was loaded?
    /// Read by `onboarding_challenge_composed.rules_edited` (analytics only) —
    /// resets when a preset (re)loads its defaults, true on any manual rule edit.
    private(set) var rulesEdited = false

    /// `initialPreset` decouples the selected chip from the "recommended" label —
    /// the post-challenge cover recommends the superior preset but may seed a
    /// different starting selection. `initialRules` seeds a custom set (Restart
    /// harder = reused rules + escalation); nil falls back to the preset defaults.
    /// Changing a chip afterward still reloads that preset's defaults (chip semantics).
    init(store: GameStore, recommendedPreset: ChallengePreset = .monk60,
         initialPreset: ChallengePreset? = nil, initialRules: [EditableRule]? = nil,
         origin: ChallengeOrigin = .home) {
        self.store = store
        self.recommendedPreset = recommendedPreset
        self.origin = origin
        let start = initialPreset ?? recommendedPreset
        self.selectedPreset = start
        self.rules = initialRules ?? PresetCatalog.definition(for: start).defaultRules
    }

    // MARK: - Preset selection

    var definition: PresetDefinition { PresetCatalog.definition(for: selectedPreset) }
    var durationDays: Int { definition.durationDays }

    func select(_ preset: ChallengePreset) {
        guard preset != selectedPreset else { return }
        selectedPreset = preset
        rules = PresetCatalog.definition(for: preset).defaultRules
        rulesEdited = false   // fresh preset defaults = a clean baseline
    }

    /// Frame-04 chips entry point (30 / 60 / 75 / 90).
    func selectDuration(days: Int) {
        guard let definition = PresetCatalog.definition(forDays: days) else { return }
        select(definition.preset)
    }

    // MARK: - Rules

    var enabledRules: [EditableRule] { rules.filter(\.isEnabled) }
    /// The cap counts ENABLED rules (batch #12): the onboarding's 11b keeps the
    /// whole catalog visible as disabled rows — visible isn't committed.
    var canAddRule: Bool { enabledRules.count < GameConfig.maxRules }
    var showRuleCountWarning: Bool { enabledRules.count >= Self.ruleCountWarningThreshold }

    @discardableResult
    func addRule(title: String, iconName: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAddRule, !trimmed.isEmpty else { return false }
        rules.append(EditableRule(title: trimmed, iconName: iconName))
        rulesEdited = true
        return true
    }

    func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
        rulesEdited = true
    }

    func toggleRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        // Enabling respects the cap; disabling is always allowed.
        if !rules[index].isEnabled {
            guard enabledRules.count < GameConfig.maxRules else { return }
        }
        rules[index].isEnabled.toggle()
        rulesEdited = true
    }

    func updateRule(id: UUID, title: String, iconName: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = rules.firstIndex(where: { $0.id == id }), !trimmed.isEmpty else { return }
        rules[index].title = trimmed
        rules[index].iconName = iconName
        rulesEdited = true
    }

    /// Time rules bake the value into the title — the checklist stays dumb strings.
    func setWakeTime(id: UUID, minutes: Int) {
        guard let index = rules.firstIndex(where: { $0.id == id }),
              rules[index].valueKind == .time else { return }
        rules[index].timeMinutes = minutes
        rules[index].title = "Wake up before \(EditableRule.formattedTime(minutes: minutes))"
        rulesEdited = true
    }

    // MARK: - Recap (screen 3 / standalone CTA)

    var startingOVR: Int { OVREngine.displayedOVR(store.player?.ovrValue ?? 0) }
    var startDate: Date { store.effectiveToday }

    /// Exact last day of the challenge — day 1 is today (decision 2026-07-12).
    var endDate: Date {
        store.displayCalendar.date(byAdding: .day, value: durationDays - 1, to: startDate)
            ?? startDate
    }

    // MARK: - Commit

    /// OB 11 gate — composing only. That CTA walks to the loader (the challenge
    /// is born at OB 19), so "no active challenge" is NOT part of this gate: it
    /// belongs to `canCommit`, which LAUNCHES. Gating compose on it left the
    /// onboarding CTA dead whenever a challenge lingered in the store.
    var canCompose: Bool { !enabledRules.isEmpty }

    var canCommit: Bool { canCompose && store.activeChallenge == nil }

    /// Maps ENABLED rules to drafts and starts the challenge. False = store
    /// refused (already active, empty rules) — the UI keeps its guard anyway.
    @discardableResult
    func commit() -> Bool {
        guard canCommit else { return false }
        let drafts = enabledRules.map(\.draft)
        return store.startChallenge(preset: selectedPreset, durationDays: durationDays,
                                    rules: drafts, reminderMinutes: reminderMinutes,
                                    origin: origin) != nil
    }
}
