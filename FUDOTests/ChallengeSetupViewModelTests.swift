import Foundation
import SwiftData
import Testing
@testable import FUDO

/// SwiftData suite → serialized + SwiftDataTestSupport, never its own container.
@Suite(.serialized)
@MainActor
struct ChallengeSetupViewModelTests {

    private func makeViewModel(recommended: ChallengePreset = .monk30,
                               startingOVR: Double = 49) throws
    -> (ChallengeSetupViewModel, GameStore) {
        let container = try SwiftDataTestSupport.freshContainer()
        let store = GameStore(modelContext: container.mainContext)
        store.ensurePlayer(startingOVR: startingOVR)
        return (ChallengeSetupViewModel(store: store, recommendedPreset: recommended), store)
    }

    // MARK: - Presets

    @Test func recommendedPresetIsPreselectedWithItsRules() throws {
        let (vm, _) = try makeViewModel(recommended: .hardcore90)
        #expect(vm.selectedPreset == .hardcore90)
        #expect(vm.durationDays == 90)
        #expect(vm.rules.count == 8)   // monk core 5 + meditate + no alcohol + journal
    }

    @Test func chipDaysMapToPresets() throws {
        let (vm, _) = try makeViewModel()
        #expect(PresetCatalog.chipDays == [30, 60, 75, 90])
        vm.selectDuration(days: 75)
        #expect(vm.selectedPreset == .classic75)
        vm.selectDuration(days: 60)
        #expect(vm.selectedPreset == .monk60)
    }

    @Test func switchingPresetDiscardsEdits() throws {
        let (vm, _) = try makeViewModel()
        vm.addRule(title: "Custom rule", iconName: "flame.fill")
        vm.select(.monk60)
        #expect(vm.rules == PresetCatalog.definition(for: .monk60).defaultRules)
    }

    @Test func classic75ProgressPhotoShipsDisabled() throws {
        let (vm, _) = try makeViewModel(recommended: .classic75)
        let photo = try #require(vm.rules.first { $0.title == "Progress photo" })
        #expect(!photo.isEnabled)
        #expect(vm.enabledRules.count == 4)
    }

    // MARK: - Rule editing

    @Test func ruleCapAtEight() throws {
        let (vm, _) = try makeViewModel(recommended: .monk30)   // 5 rules
        #expect(vm.addRule(title: "Six", iconName: "flame.fill"))
        #expect(vm.addRule(title: "Seven", iconName: "flame.fill"))
        #expect(vm.addRule(title: "Eight", iconName: "flame.fill"))
        #expect(!vm.canAddRule)
        #expect(!vm.addRule(title: "Nine", iconName: "flame.fill"))
        #expect(vm.rules.count == GameConfig.maxRules)
    }

    @Test func warningFromSeventhEnabledRule() throws {
        let (vm, _) = try makeViewModel(recommended: .monk30)   // 5 enabled
        vm.addRule(title: "Six", iconName: "flame.fill")
        #expect(!vm.showRuleCountWarning)
        vm.addRule(title: "Seven", iconName: "flame.fill")
        #expect(vm.showRuleCountWarning)
    }

    @Test func emptyOrBlankTitlesRejected() throws {
        let (vm, _) = try makeViewModel()
        #expect(!vm.addRule(title: "   ", iconName: "flame.fill"))
        let first = try #require(vm.rules.first)
        vm.updateRule(id: first.id, title: "  ", iconName: "flame.fill")
        #expect(vm.rules.first?.title == first.title)   // unchanged
    }

    @Test func wakeTimeBakesIntoTitle() throws {
        let (vm, _) = try makeViewModel()
        let wake = try #require(vm.rules.first { $0.valueKind == .time })
        vm.setWakeTime(id: wake.id, minutes: 6 * 60 + 30)
        let updated = try #require(vm.rules.first { $0.id == wake.id })
        #expect(updated.title == "Wake up before 6:30")
        #expect(updated.timeMinutes == 390)
    }

    @Test func toggleDisablesWithoutRemoving() throws {
        let (vm, _) = try makeViewModel()
        let first = try #require(vm.rules.first)
        vm.toggleRule(id: first.id)
        #expect(vm.rules.count == 5)
        #expect(vm.enabledRules.count == 4)
    }

    // MARK: - Commit

    @Test func commitStartsChallengeWithEnabledRulesOnly() throws {
        let (vm, store) = try makeViewModel(recommended: .classic75)
        #expect(vm.commit())
        let challenge = try #require(store.activeChallenge)
        #expect(challenge.preset == .classic75)
        #expect(challenge.durationDays == 75)
        #expect(challenge.rules.count == 4)   // progress photo disabled → not created
        #expect(challenge.reminderMinutes == ChallengeSetupViewModel.defaultReminderMinutes)
    }

    @Test func commitRefusedWhenChallengeAlreadyActive() throws {
        let (vm, store) = try makeViewModel()
        #expect(vm.commit())
        let second = ChallengeSetupViewModel(store: store)
        #expect(!second.canCommit)
        #expect(!second.commit())
    }

    @Test func endDateIsExactLastDay() throws {
        let (vm, store) = try makeViewModel()   // monk30, day 1 = today
        let expected = try #require(store.displayCalendar.date(byAdding: .day, value: 29,
                                                               to: store.effectiveToday))
        #expect(vm.endDate == expected)
    }

    // MARK: - Model

    @Test func canEditRulesLocksAfterDayThree() throws {
        let container = try SwiftDataTestSupport.freshContainer()
        var day1 = try #require(Calendar.current.date(from: DateComponents(
            year: 2026, month: 3, day: 10, hour: 9)))
        let store = GameStore(modelContext: container.mainContext,
                              calendar: .current, nowProvider: { day1 })
        store.ensurePlayer(startingOVR: 49)
        let vm = ChallengeSetupViewModel(store: store)
        #expect(vm.commit())
        let challenge = try #require(store.activeChallenge)
        #expect(challenge.canEditRules(now: day1))
        day1 = try #require(Calendar.current.date(byAdding: .day, value: 2, to: day1))
        #expect(challenge.canEditRules(now: day1))    // day 3 inclusive
        day1 = try #require(Calendar.current.date(byAdding: .day, value: 1, to: day1))
        #expect(!challenge.canEditRules(now: day1))   // day 4 locked
    }
}
