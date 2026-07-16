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

    private(set) var selectedPreset: ChallengePreset
    var rules: [EditableRule]
    var reminderMinutes: Int = ChallengeSetupViewModel.defaultReminderMinutes

    init(store: GameStore, recommendedPreset: ChallengePreset = .monk60) {
        self.store = store
        self.recommendedPreset = recommendedPreset
        self.selectedPreset = recommendedPreset
        self.rules = PresetCatalog.definition(for: recommendedPreset).defaultRules
    }

    // MARK: - Preset selection

    var definition: PresetDefinition { PresetCatalog.definition(for: selectedPreset) }
    var durationDays: Int { definition.durationDays }

    func select(_ preset: ChallengePreset) {
        guard preset != selectedPreset else { return }
        selectedPreset = preset
        rules = PresetCatalog.definition(for: preset).defaultRules
    }

    /// Frame-04 chips entry point (30 / 60 / 75 / 90).
    func selectDuration(days: Int) {
        guard let definition = PresetCatalog.definition(forDays: days) else { return }
        select(definition.preset)
    }

    // MARK: - Rules

    var enabledRules: [EditableRule] { rules.filter(\.isEnabled) }
    var canAddRule: Bool { rules.count < GameConfig.maxRules }
    var showRuleCountWarning: Bool { enabledRules.count >= Self.ruleCountWarningThreshold }

    @discardableResult
    func addRule(title: String, iconName: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAddRule, !trimmed.isEmpty else { return false }
        rules.append(EditableRule(title: trimmed, iconName: iconName))
        return true
    }

    func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    func toggleRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].isEnabled.toggle()
    }

    func updateRule(id: UUID, title: String, iconName: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = rules.firstIndex(where: { $0.id == id }), !trimmed.isEmpty else { return }
        rules[index].title = trimmed
        rules[index].iconName = iconName
    }

    /// Time rules bake the value into the title — the checklist stays dumb strings.
    func setWakeTime(id: UUID, minutes: Int) {
        guard let index = rules.firstIndex(where: { $0.id == id }),
              rules[index].valueKind == .time else { return }
        rules[index].timeMinutes = minutes
        rules[index].title = "Wake up before \(EditableRule.formattedTime(minutes: minutes))"
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
                                    rules: drafts, reminderMinutes: reminderMinutes) != nil
    }
}
