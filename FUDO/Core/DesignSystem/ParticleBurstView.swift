import SwiftUI

/// Particle counts — no magic numbers in views (CLAUDE.md).
enum ParticleBurstMetrics {
    /// Micro burst on a single check.
    static let checkCount = 10
    /// Gold milestone burst (100 % day, rank-up, challenge complete).
    static let celebrationCount = 14
}

/// One-shot radial particle burst. Zero intrinsic size — place it with an overlay
/// at the epicenter. Particles are frozen at init so re-renders never reshuffle a
/// burst mid-flight; give the view a fresh `.id` to replay it. The parent removes
/// the view after the run.
struct ParticleBurstView: View {
    private struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
    }

    private let color: Color
    private let startDistance: CGFloat
    private let animation: Animation
    @State private var particles: [Particle]
    @State private var expanded = false

    init(color: Color,
         particleCount: Int = ParticleBurstMetrics.checkCount,
         distance: ClosedRange<CGFloat> = 34...52,
         particleSize: ClosedRange<CGFloat> = 2.5...4.5,
         startDistance: CGFloat = 6,
         animation: Animation = AppAnimation.standard) {
        self.color = color
        self.startDistance = startDistance
        self.animation = animation
        _particles = State(initialValue: (0..<particleCount).map { index in
            Particle(id: index,
                     angle: (Double(index) / Double(particleCount)) * 2 * .pi + .random(in: -0.15...0.15),
                     distance: .random(in: distance),
                     size: .random(in: particleSize))
        })
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: cos(particle.angle) * (expanded ? particle.distance : startDistance),
                            y: sin(particle.angle) * (expanded ? particle.distance : startDistance))
                    .opacity(expanded ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(animation) { expanded = true }
        }
    }
}
