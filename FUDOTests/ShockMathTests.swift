import Testing
@testable import FUDO

struct ShockMathTests {

    @Test func theHeadlineHorizonIsTheBracketsRoundDecade() {
        #expect(ShockMath.result(age: .teen1317, scroll: .fourToSixHours).horizonAge == 30)
        #expect(ShockMath.result(age: .young1824, scroll: .fourToSixHours).horizonAge == 30)
        #expect(ShockMath.result(age: .adult2534, scroll: .fourToSixHours).horizonAge == 40)
        #expect(ShockMath.result(age: .mature35plus, scroll: .fourToSixHours).horizonAge == 50)
        // Senior bracket (tester batch #1): the shock math works at any age.
        #expect(ShockMath.result(age: .senior55plus, scroll: .fourToSixHours).horizonAge == 70)
    }

    @Test func fourToSixHoursAtTwentyOneCostsNineYearsOfEvenings() {
        let result = ShockMath.result(age: .young1824, scroll: .fourToSixHours)
        // 5 h/day × 9 years / 24 h = 1.875 → 1.9
        #expect(abs(result.years - 1.875) < 0.001)
        #expect(result.headline == "1.9 years")
    }

    @Test func theHeaviestScrollerIsTheHeaviestNumber() {
        #expect(ShockMath.result(age: .teen1317, scroll: .sixHoursPlus).headline == "4.4 years")
    }

    @Test func underOneYearSwitchesToDaysBecauseZeroPointSixDoesNotLand() {
        let result = ShockMath.result(age: .young1824, scroll: .underTwoHours)
        #expect(result.years < 1)
        #expect(result.headline == "205 days")
    }

    @Test func moreScrollingIsAlwaysMoreYears() {
        // Monotonic in the scroll answer: the shock can never reward more scrolling.
        let ordered: [OnboardingAnswers.ScrollTime] = [.underTwoHours, .twoToFourHours,
                                                       .fourToSixHours, .sixHoursPlus]
        for age in AgeBracket.allCases {
            let years = ordered.map { ShockMath.result(age: age, scroll: $0).years }
            #expect(years == years.sorted())
        }
    }

    @Test func everyCombinationProducesAReadableNumber() {
        // No combination may render an empty or absurd headline — 16 screens' worth.
        for age in AgeBracket.allCases {
            for scroll in OnboardingAnswers.ScrollTime.allCases {
                let result = ShockMath.result(age: age, scroll: scroll)
                #expect(result.years > 0)
                #expect(result.headline.hasSuffix("years") || result.headline.hasSuffix("days"))
            }
        }
    }
}
