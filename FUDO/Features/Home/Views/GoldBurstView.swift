import SwiftUI

/// One-shot discreet gold burst — `celebrationGold` ONLY, milestone moments ONLY
/// (100 % day here; rank-up and challenge-complete reuse it later). Thin preset
/// over the design-system ParticleBurstView.
struct GoldBurstView: View {
    var body: some View {
        ParticleBurstView(color: FudoColor.celebrationGold,
                          particleCount: ParticleBurstMetrics.celebrationCount,
                          distance: 105...150,
                          particleSize: 3...6,
                          startDistance: 12,
                          animation: AppAnimation.slow)
    }
}
