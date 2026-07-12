import SwiftUI

/// Particle counts — no magic numbers in views (CLAUDE.md).
enum ParticleBurstMetrics {
    /// Micro burst on a single check.
    static let checkCount = 10
    /// Gold milestone burst (rank-up, challenge complete).
    static let celebrationCount = 14
    /// Fuller gold+vermillon ring burst for the 100 % day moment.
    static let dayCompleteCount = 22
}

/// One-shot radial particle burst. Zero intrinsic size — place it with an overlay
/// at the epicenter; `originRadius` > 0 emits from a circle (e.g. the day ring)
/// instead of a point. Particles are frozen at init so re-renders never reshuffle
/// a burst mid-flight; give the view a fresh `.id` to replay it. The parent
/// removes the view after the run.
struct ParticleBurstView: View {
    private struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: Color
    }

    private let startDistance: CGFloat
    private let originRadius: CGFloat
    private let animation: Animation
    @State private var particles: [Particle]
    @State private var expanded = false

    init(colors: [Color],
         particleCount: Int = ParticleBurstMetrics.checkCount,
         distance: ClosedRange<CGFloat> = 34...52,
         particleSize: ClosedRange<CGFloat> = 2.5...4.5,
         startDistance: CGFloat = 6,
         originRadius: CGFloat = 0,
         animation: Animation = AppAnimation.standard) {
        self.startDistance = startDistance
        self.originRadius = originRadius
        self.animation = animation
        let palette = colors.isEmpty ? [FudoColor.accent] : colors
        _particles = State(initialValue: (0..<particleCount).map { index in
            Particle(id: index,
                     angle: (Double(index) / Double(particleCount)) * 2 * .pi + .random(in: -0.15...0.15),
                     distance: .random(in: distance),
                     size: .random(in: particleSize),
                     color: palette[index % palette.count])
        })
    }

    init(color: Color,
         particleCount: Int = ParticleBurstMetrics.checkCount,
         distance: ClosedRange<CGFloat> = 34...52,
         particleSize: ClosedRange<CGFloat> = 2.5...4.5,
         startDistance: CGFloat = 6,
         originRadius: CGFloat = 0,
         animation: Animation = AppAnimation.standard) {
        self.init(colors: [color], particleCount: particleCount, distance: distance,
                  particleSize: particleSize, startDistance: startDistance,
                  originRadius: originRadius, animation: animation)
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: cos(particle.angle) * radius(for: particle),
                            y: sin(particle.angle) * radius(for: particle))
                    .opacity(expanded ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(animation) { expanded = true }
        }
    }

    private func radius(for particle: Particle) -> CGFloat {
        originRadius + (expanded ? particle.distance : startDistance)
    }
}
