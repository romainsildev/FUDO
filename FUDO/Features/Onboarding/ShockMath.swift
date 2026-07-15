import Foundation

/// OB 06's number. Pure and self-contained: hours/day × years-to-the-horizon ÷ 24.
/// No study, no source, no claim about the world — just his own two answers,
/// multiplied. That's why it lands, and that's why it survives a fact-check.
enum ShockMath {
    struct Result: Equatable {
        let years: Double
        let horizonAge: Int
        /// "2.4 years" — or "205 days" under a year, because "0.6 years" lands on nobody.
        let headline: String
    }

    /// Where the sentence points: the round decade his answers make concrete.
    /// Tunable — this is the honest lever if the number should hit harder.
    private static func pivotAge(_ bracket: AgeBracket) -> Int {
        switch bracket {
        case .teen1317: return 15
        case .young1824: return 21
        case .adult2534: return 29
        case .mature35plus: return 40
        }
    }

    private static func horizonAge(_ bracket: AgeBracket) -> Int {
        switch bracket {
        case .teen1317, .young1824: return 30
        case .adult2534: return 40
        case .mature35plus: return 50
        }
    }

    private static func hoursPerDay(_ scroll: OnboardingAnswers.ScrollTime) -> Double {
        switch scroll {
        case .underTwoHours: return 1.5
        case .twoToFourHours: return 3
        case .fourToSixHours: return 5
        case .sixHoursPlus: return 7
        }
    }

    static func result(age: AgeBracket, scroll: OnboardingAnswers.ScrollTime) -> Result {
        let horizon = horizonAge(age)
        let span = Double(horizon - pivotAge(age))
        let years = hoursPerDay(scroll) * span / 24
        return Result(years: years, horizonAge: horizon, headline: headline(for: years))
    }

    /// Internal, not private: the OB 06 count-up re-formats the animating value
    /// through this exact rule, so the number in flight and the number at rest
    /// can never be written two different ways.
    static func headline(for years: Double) -> String {
        if years < 1 {
            return "\(Int((years * 365).rounded())) days"
        }
        return "\((years * 10).rounded() / 10) years"
    }
}
