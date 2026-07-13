import SwiftUI

/// The trophy-room hero: the current rank's sensei near full-width, the OVR as the single
/// biggest number in the app, and the rank line beneath. Composed for a 9:16 screen recording
/// — the sensei + number sit centred so nothing critical lands in the top corners.
/// Exact art size / crop is tuned on device (Romain).
struct SenseiHeroView: View {
    let rank: Rank
    let ovr: Int
    let rankName: String
    let ordinal: String

    /// Near full-width portrait; capped in height so the giant OVR stays above the fold.
    private let portraitHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 12) {
            SenseiAssetProvider.image(for: rank)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: portraitHeight)
                .accessibilityLabel("\(rankName) sensei")

            VStack(spacing: 2) {
                Text("\(ovr)")
                    .font(FudoFont.ovr(96))
                    .foregroundStyle(FudoColor.textPrimary)
                    .contentTransition(.numericText())
                Text("OVR")
                    .font(FudoFont.caption(15))
                    .tracking(3)
                    .foregroundStyle(FudoColor.textSecondary)
            }

            Text("\(rankName.uppercased())  —  \(ordinal.uppercased())")
                .font(FudoFont.caption(14).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(FudoColor.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(heroGlow)
    }

    /// A faint vermillon halo behind the hero (accent territory, well under the 10 % budget).
    /// Not a celebration — it's the ambient "hero shot" light.
    private var heroGlow: some View {
        RadialGradient(colors: [FudoColor.accentDeep.opacity(0.32), .clear],
                       center: .center, startRadius: 8, endRadius: 240)
            .blur(radius: 24)
            .allowsHitTesting(false)
    }
}
