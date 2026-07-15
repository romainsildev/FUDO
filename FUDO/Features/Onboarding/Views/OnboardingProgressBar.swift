import SwiftUI

/// The funnel's only progress feedback. The fraction comes from OnboardingStep —
/// counted from the enum, never hand-numbered — and the bar SLIDES between
/// screens, which is what makes a 15-question funnel feel like it's moving.
///
/// A nil fraction renders nothing at all (not an empty track): the screens
/// without a bar pull their content up, exactly like the frames.
struct OnboardingProgressBar: View {
    let fraction: Double?

    private static let height: CGFloat = 3

    var body: some View {
        if let fraction {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FudoColor.border)
                    Capsule()
                        .fill(FudoColor.accent)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: Self.height)
            .animation(AppAnimation.standard, value: fraction)
        }
    }
}
