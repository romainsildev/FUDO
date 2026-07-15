import SwiftUI

/// The two layers that ALWAYS sit between the welcome video and the hooks: a
/// vertical wash so the copy holds on any frame, and the focus vignette.
///
/// Its own component because the flow and the canvas previews must show the same
/// thing — a hook previewed without its scrim is a hook nobody can judge.
struct WelcomeScrim: View {
    /// The splash reinforces it: that screen is a focal point, not a set.
    var isSplash = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [FudoColor.bgPrimary.opacity(0.35),
                                    FudoColor.bgPrimary.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.clear, FudoColor.bgPrimary.opacity(isSplash ? 0.85 : 0.75)],
                           center: .center,
                           startRadius: isSplash ? 60 : 120,
                           endRadius: 420)
        }
        .allowsHitTesting(false)
    }
}
