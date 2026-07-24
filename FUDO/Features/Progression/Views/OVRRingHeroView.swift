import SwiftUI

/// The Progression hero (02 Progression, 2026-07-24 — Romain's re-skin): the OVR as the
/// single biggest number in the app, held inside a ring whose vermillon arc fills with the
/// player's progress THROUGH the current rank band. The rank line sits below. The sensei
/// portrait is gone from the hero — it now lives on the current node of the path.
struct OVRRingHeroView: View {
    let rank: Rank
    let ovr: Int
    let rankName: String
    let ordinal: String
    let progress: Double     // 0…1 within the current rank band

    private let ringSize: CGFloat = 170
    private let ringWidth: CGFloat = 7

    /// The drawn arc: a freshly-entered rank (progress ≈ 0) still shows a small starter
    /// spark — a dead-empty ring reads as "broken", not "day one of the climb".
    private var arcProgress: Double { max(progress, 0.03) }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(FudoColor.textPrimary.opacity(0.15), lineWidth: ringWidth)

                Circle()
                    .trim(from: 0, to: arcProgress)
                    .stroke(FudoColor.accent,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(ovr)")
                        .fudoFont(.ovr(56))
                        .foregroundStyle(FudoColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("OVR")
                        .fudoFont(.caption(12, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(FudoColor.textSecondary)
                }
            }
            .frame(width: ringSize, height: ringSize)
            // Ambient hero glow — a background so it never inflates the layout (a sized
            // sibling in the ZStack made the whole hero balloon past the ring, device
            // 2026-07-24). Accent territory, well under the 10 % budget.
            .background {
                Circle()
                    .fill(FudoColor.accent.opacity(0.10))
                    .padding(-24)
                    .blur(radius: 40)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("OVR \(ovr), \(rankName)")

            Text("\(rankName.uppercased())  —  \(ordinal.uppercased())")
                .fudoFont(.caption(13, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(FudoColor.accent)
        }
        .frame(maxWidth: .infinity)
        .animation(AppAnimation.standard, value: progress)
    }
}

#if DEBUG
#Preview("OVR ring hero") {
    ScrollView {
        VStack(spacing: 48) {
            OVRRingHeroView(rank: .ascetic, ovr: 60, rankName: "Ascetic",
                            ordinal: "Rank 3 of 6", progress: 0)      // starter spark
            OVRRingHeroView(rank: .disciple, ovr: 59, rankName: "Disciple",
                            ordinal: "Rank 2 of 6", progress: 0.9)
            OVRRingHeroView(rank: .sensei, ovr: 96, rankName: "Sensei",
                            ordinal: "Rank 6 of 6", progress: 1.0)
        }
    }
    .padding(FudoSpacing.screenMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FudoColor.bgPrimary)
    .preferredColorScheme(.dark)
}
#endif
