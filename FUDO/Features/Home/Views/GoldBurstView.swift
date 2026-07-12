import SwiftUI

/// One-shot discreet gold burst — `celebrationGold` ONLY, milestone moments ONLY
/// (100 % day here; rank-up and challenge-complete reuse it later). Fourteen small
/// particles radiate once and fade; the parent removes the view after the run.
struct GoldBurstView: View {
    private struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
    }

    /// Frozen at first render so re-renders never reshuffle a burst mid-flight.
    @State private var particles: [Particle] = (0..<14).map { index in
        Particle(id: index,
                 angle: (Double(index) / 14) * 2 * .pi + .random(in: -0.15...0.15),
                 distance: .random(in: 105...150),
                 size: .random(in: 3...6))
    }
    @State private var expanded = false

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(FudoColor.celebrationGold)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: cos(particle.angle) * (expanded ? particle.distance : 12),
                            y: sin(particle.angle) * (expanded ? particle.distance : 12))
                    .opacity(expanded ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(AppAnimation.slow) { expanded = true }
        }
    }
}
