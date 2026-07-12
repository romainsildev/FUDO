import Testing
@testable import FUDO

struct GameConfigTests {
    @Test func constantsMatchDataModel() {
        #expect(GameConfig.ovrMax == 99.0)
        #expect(GameConfig.baseOVRMin == 40)
        #expect(GameConfig.baseOVRMax == 50)
        #expect(GameConfig.dailyRate == 0.033)
        #expect(GameConfig.penaltyFactor == 2.0)
        #expect(GameConfig.penaltyMin == 2.0)
        #expect(GameConfig.graceHours == 2)
        #expect(GameConfig.decayStartDays == 7)
        #expect(GameConfig.decayIntervalDays == 3)
        #expect(GameConfig.decayAmount == 1.0)
        #expect(GameConfig.maxRules == 8)
        #expect(GameConfig.rulesLockDay == 3)
    }
}
