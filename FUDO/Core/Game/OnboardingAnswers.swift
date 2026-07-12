import Foundation

/// Typed onboarding answers → starting-OVR points (DATA-MODEL §3a).
/// Each case carries its own points so the scale lives here and nowhere else;
/// the onboarding screens (é2/é4/é7/é13) will map their options onto these cases.
struct OnboardingAnswers: Equatable {
    let scrollTime: ScrollTime
    let procrastination: Procrastination
    let struggle: Struggle
    let commitment: Commitment

    enum ScrollTime: CaseIterable {
        case underTwoHours, twoToFourHours, fourToSixHours, sixHoursPlus
        var points: Int {
            switch self {
            case .underTwoHours: 4
            case .twoToFourHours: 3
            case .fourToSixHours: 1
            case .sixHoursPlus: 0
            }
        }
    }

    enum Procrastination: CaseIterable {
        case stoppedLyingToMyself, everyMonth, everyWeek
        var points: Int {
            switch self {
            case .stoppedLyingToMyself: 2
            case .everyMonth: 1
            case .everyWeek: 0
            }
        }
    }

    enum Struggle: CaseIterable {
        case startStrongThenQuit, threeDaysMax, cantEvenStart
        var points: Int {
            switch self {
            case .startStrongThenQuit: 2
            case .threeDaysMax: 1
            case .cantEvenStart: 0
            }
        }
    }

    enum Commitment: CaseIterable {
        case extremely, very, somewhat
        var points: Int {
            switch self {
            case .extremely: 2
            case .very: 1
            case .somewhat: 0
            }
        }
    }

    var totalPoints: Int {
        scrollTime.points + procrastination.points + struggle.points + commitment.points
    }
}
