import SwiftUI

/// The value screens run warmer than the questions. OB 06, 09, 12, 14 and 19 sit
/// on this wash: the quiz is cold and factual, the beats glow. One recipe, so the
/// two acts can't drift apart.
struct OnboardingWarmWash: View {
    /// Where the heat comes from. `.top` for the reading beats (06, 09, 12, 19),
    /// `.bottom` for OB 14 — there the heat is the ring he's about to hold.
    enum Source { case top, bottom }

    var source: Source = .top

    private static let washOpacity: Double = 0.35
    private static let bottomOpacity: Double = 0.30

    var body: some View {
        ZStack {
            FudoColor.bgPrimary
            switch source {
            case .top:
                LinearGradient(colors: [FudoColor.accentDeep.opacity(Self.washOpacity), .clear],
                               startPoint: .top, endPoint: .center)
            case .bottom:
                RadialGradient(colors: [FudoColor.accentDeep.opacity(Self.bottomOpacity), .clear],
                               center: .init(x: 0.5, y: 0.66), startRadius: 20, endRadius: 320)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    /// Sets the warm wash behind a value screen.
    func onboardingWarmWash(_ source: OnboardingWarmWash.Source = .top) -> some View {
        background { OnboardingWarmWash(source: source) }
    }
}
