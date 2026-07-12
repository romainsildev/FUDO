import Testing
@testable import FUDO

struct NavigationTests {
    @Test func fourTabsInOrder() {
        #expect(AppTab.allCases == [.today, .progress, .stats, .settings])
    }

    @Test func tabTitles() {
        #expect(AppTab.today.title == "Today")
        #expect(AppTab.progress.title == "Progress")
        #expect(AppTab.stats.title == "Stats")
        #expect(AppTab.settings.title == "Settings")
    }

    @Test func sheetAndCoverAreIdentifiable() {
        #expect(FudoSheet.flame.id != FudoSheet.shareCard.id)
        #expect(FudoCover.onboarding.id != FudoCover.paywall.id)
    }

    @Test func visibilityDefaultsVisible() {
        #expect(TabBarVisibility().isHidden == false)
    }
}
