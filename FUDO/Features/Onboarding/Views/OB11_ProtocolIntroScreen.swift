import SwiftUI

/// The EXPLAINER (batch #2, Romain) — one sentence between the reveal and 11a:
/// "we've picked your actions" gets its own beat, so 11a can be the duration
/// question and nothing else. One idea per screen, taken literally.
struct ProtocolIntroScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        OnboardingScaffold(step: .protocolIntro, canAdvance: true,
                           centersVertically: true, onAdvance: onAdvance) {
            Text("We've picked your actions\nfrom your answers.")
                .fudoFont(.title(28, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("Explainer — one sentence") {
    OnboardingPreviewChrome {
        ProtocolIntroScreen(onAdvance: {})
    }
}
#endif
