import Testing
@testable import FUDO

/// The pure share-card copy mapping (primitives in, String out — no @Model, so it
/// runs in a plain suite). The data→card factories that read the store are covered
/// by compile + device; here we lock the framing strings.
struct ShareCardCopyTests {

    // MARK: dayLine

    @Test func dayLineActiveChallengeShowsDayAndPreset() {
        #expect(ShareCardCopy.dayLine(day: 12, total: 30, preset: "Monk Mode 30")
                == "DAY 12 / 30  ·  MONK MODE 30")
    }

    @Test func dayLineFinishedRunDropsTheLiveDay() {
        #expect(ShareCardCopy.dayLine(day: nil, total: 30, preset: "Monk Mode 30")
                == "30 DAYS  ·  MONK MODE 30")
    }

    @Test func dayLineWithoutPresetIsJustTheDuration() {
        #expect(ShareCardCopy.dayLine(day: 7, total: 60, preset: nil) == "DAY 7 / 60")
    }

    @Test func dayLineNoChallengeFallsBackToPreset() {
        #expect(ShareCardCopy.dayLine(day: nil, total: nil, preset: "Monk Mode 30")
                == "MONK MODE 30")
    }

    @Test func dayLineNoChallengeNoPresetIsNil() {
        #expect(ShareCardCopy.dayLine(day: nil, total: nil, preset: nil) == nil)
    }

    // MARK: ovr journey + gain

    @Test func ovrJourneyLineIsTheClipNumber() {
        #expect(ShareCardCopy.ovrJourneyLine(start: 43, end: 76) == "43 → 76")
    }

    @Test func gainBadgeSignsThePositiveRun() {
        #expect(ShareCardCopy.ovrGainBadge(start: 43, end: 76) == "+33")
    }

    @Test func gainBadgeStaysHonestOnFlatOrNegativeRuns() {
        #expect(ShareCardCopy.ovrGainBadge(start: 50, end: 50) == "+0")
        #expect(ShareCardCopy.ovrGainBadge(start: 60, end: 55) == "-5")
    }

    // MARK: streak

    @Test func streakLineSingularAtOne() {
        #expect(ShareCardCopy.streakLine(1) == "1 DAY STREAK")
    }

    @Test func streakLinePluralOtherwise() {
        #expect(ShareCardCopy.streakLine(4) == "4 DAY STREAK")
        #expect(ShareCardCopy.streakLine(0) == "0 DAY STREAK")
    }
}
