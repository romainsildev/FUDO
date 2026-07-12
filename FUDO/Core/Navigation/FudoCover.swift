import SwiftUI

/// COVER destinations — full screen, NO gesture dismiss. Moments of flow.
enum FudoCover: Identifiable {
    case onboarding, paywall, challengeSetup, challengeComplete, rankUp
    var id: Int {
        switch self {
        case .onboarding: return 0
        case .paywall: return 1
        case .challengeSetup: return 2
        case .challengeComplete: return 3
        case .rankUp: return 4
        }
    }
}

extension View {
    func fudoCover<Content: View>(
        item: Binding<FudoCover?>,
        @ViewBuilder content: @escaping (FudoCover) -> Content
    ) -> some View {
        fullScreenCover(item: item) { cover in
            content(cover).interactiveDismissDisabled(true)
        }
    }
}
