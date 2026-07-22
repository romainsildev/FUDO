import SwiftUI

/// Which story card is being composed.
enum ShareCardVariant {
    case daily        // sensei + giant OVR + rank + streak + day X/Y
    case rankUp       // the new rank in scene, celebration energy
    case challengeEnd // OVR 43 → 76 — the number of the clip (template, wired S11)
}

/// The 9:16 story card — ONE fixed canvas rendered to a UIImage at 3× (1080×1920).
/// Designed in points (360×640) so `.fudoFont` sizes read like everywhere else;
/// the renderer scales. Pure data in — no GameStore, so `ImageRenderer` runs it
/// off-screen. This is the asset the TikTok clips show: treated like a real screen.
struct ShareCardView: View {
    let data: ShareCardData
    var variant: ShareCardVariant = .daily

    /// Point canvas. 360 × 16/9 = 640 → exactly 9:16.
    static let canvas = CGSize(width: 360, height: 640)

    private var isCelebration: Bool { variant == .rankUp }

    var body: some View {
        ZStack {
            FudoColor.bgPrimary
            glow
            content
                .padding(.top, 40)
                .padding(.bottom, 84)   // clears the branding footer
                .padding(.horizontal, 28)
            brandingFooter
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 30)
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .clipped()
    }

    // MARK: - Content per variant

    @ViewBuilder
    private var content: some View {
        switch variant {
        case .daily:        dailyContent
        case .rankUp:       rankUpContent
        case .challengeEnd: challengeEndContent
        }
    }

    /// Sensei + giant OVR hero, streak on top, day line at the foot.
    private var dailyContent: some View {
        VStack(spacing: 0) {
            if data.streak > 0 { streakPill } else { brandEyebrow }
            Spacer(minLength: 8)
            senseiPortrait(height: 224)
            giantOVR(size: 104)
            rankName(size: 38)
            Spacer(minLength: 8)
            if let line = ShareCardCopy.dayLine(day: data.dayNumber, total: data.totalDays, preset: data.presetTitle) {
                metaLine(line)
            }
        }
    }

    /// The rank just crossed, put in scene — gold + vermillon celebration.
    private var rankUpContent: some View {
        VStack(spacing: 0) {
            eyebrow("RANK UP", color: FudoColor.celebrationGold)
            Spacer(minLength: 8)
            senseiPortrait(height: 250)
            rankName(size: 50)
            Text("OVR \(data.ovr)")
                .fudoFont(.metric(22))
                .kerning(2)
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.top, 6)
            Spacer(minLength: 12)
            metaLine("NEW RANK UNLOCKED")
        }
    }

    /// The delta run: "43 → 76" — the number the clip is built around.
    private var challengeEndContent: some View {
        VStack(spacing: 0) {
            eyebrow("CHALLENGE COMPLETE", color: FudoColor.accent)
            Spacer(minLength: 8)
            senseiPortrait(height: 200)
            Text("OVR")
                .fudoFont(.caption(14))
                .kerning(4)
                .foregroundStyle(FudoColor.textSecondary)
                .padding(.top, 4)
            journeyLine
            if let start = data.startOVR, let end = data.endOVR {
                gainBadge(start: start, end: end)
                    .padding(.top, 8)
            }
            rankName(size: 34)
                .padding(.top, 10)
            Spacer(minLength: 12)
            if let line = ShareCardCopy.dayLine(day: nil, total: data.totalDays, preset: data.presetTitle) {
                metaLine(line)
            }
        }
    }

    // MARK: - Pieces

    private func senseiPortrait(height: CGFloat) -> some View {
        SenseiAssetProvider.image(for: data.rank)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityHidden(true)
    }

    private func giantOVR(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("\(data.ovr)")
                .fudoFont(.ovr(size))
                .foregroundStyle(FudoColor.textPrimary)
            Text("OVR")
                .fudoFont(.caption(15))
                .kerning(5)
                .foregroundStyle(FudoColor.textSecondary)
        }
    }

    private func rankName(size: CGFloat) -> some View {
        Text(data.rank.displayName.uppercased())
            .fudoFont(.title(size, weight: .heavy))
            .kerning(size > 44 ? 2 : 3)
            .foregroundStyle(FudoColor.accent)
            .padding(.top, 8)
    }

    /// "43 → 76" — start neutral, arrow vermillon, end neutral. The big numbers
    /// stay crème so the accent budget rides the arrow + rank only.
    private var journeyLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(data.startOVR ?? data.ovr)")
                .foregroundStyle(FudoColor.textSecondary)
            Image(systemName: "arrow.right")
                .fudoFont(.glyph(40, weight: .bold))
                .foregroundStyle(FudoColor.accent)
                .baselineOffset(-4)
            Text("\(data.endOVR ?? data.ovr)")
                .foregroundStyle(FudoColor.textPrimary)
        }
        .fudoFont(.ovr(84))
    }

    /// "+33" — the arrow carries the green (palette rule), so does this signed badge.
    private func gainBadge(start: Int, end: Int) -> some View {
        let gain = end - start
        return HStack(spacing: 4) {
            Image(systemName: gain >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .fudoFont(.stat(14))
            Text(ShareCardCopy.ovrGainBadge(start: start, end: end))
                .fudoFont(.stat(18, weight: .heavy))
        }
        .foregroundStyle(gain >= 0 ? FudoColor.positive : FudoColor.negative)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(FudoColor.bgCard).overlay(Capsule().strokeBorder(FudoColor.border, lineWidth: 1)))
    }

    private var streakPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "flame.fill")
                .fudoFont(.glyph(15))
            Text(ShareCardCopy.streakLine(data.streak))
                .fudoFont(.label(13, weight: .heavy))
                .kerning(1.5)
        }
        .foregroundStyle(FudoColor.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(FudoGradient.flame))
    }

    private var brandEyebrow: some View {
        eyebrow("FUDO — MONK MODE", color: FudoColor.textSecondary)
    }

    private func eyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .fudoFont(.label(13, weight: .heavy))
            .kerning(3)
            .foregroundStyle(color)
    }

    private func metaLine(_ text: String) -> some View {
        Text(text)
            .fudoFont(.caption(13, weight: .semibold))
            .kerning(1.5)
            .foregroundStyle(FudoColor.textSecondary)
            .multilineTextAlignment(.center)
    }

    private var brandingFooter: some View {
        HStack(spacing: 8) {
            Image("enso-100")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .opacity(0.9)
            Text("FUDO")
                .fudoFont(.label(15, weight: .heavy))
                .kerning(5)
                .foregroundStyle(FudoColor.textSecondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Glow (ambient hero light, not a celebration for daily/end)

    private var glow: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accentDeep.opacity(isCelebration ? 0.42 : 0.30), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 320)
            if isCelebration {
                RadialGradient(colors: [FudoColor.celebrationGold.opacity(0.16), .clear],
                               center: UnitPoint(x: 0.5, y: 0.40), startRadius: 10, endRadius: 260)
            }
        }
        .blur(radius: 30)
        .ignoresSafeArea()
    }
}

#if DEBUG
private extension ShareCardData {
    static let previewDaily = ShareCardData(rank: .ascetic, ovr: 61, streak: 4,
                                            dayNumber: 12, totalDays: 30,
                                            presetTitle: "Monk Mode 30", startOVR: nil, endOVR: nil)
    static let previewRankUp = ShareCardData(rank: .warrior, ovr: 70, streak: 9,
                                             dayNumber: 22, totalDays: 30,
                                             presetTitle: "Monk Mode 30", startOVR: nil, endOVR: nil)
    static let previewEnd = ShareCardData(rank: .warrior, ovr: 76, streak: 21,
                                          dayNumber: 30, totalDays: 30,
                                          presetTitle: "Monk Mode 30", startOVR: 43, endOVR: 76)
}

#Preview("Daily") {
    ShareCardView(data: .previewDaily, variant: .daily).preferredColorScheme(.dark)
}
#Preview("Rank-up") {
    ShareCardView(data: .previewRankUp, variant: .rankUp).preferredColorScheme(.dark)
}
#Preview("Challenge-end") {
    ShareCardView(data: .previewEnd, variant: .challengeEnd).preferredColorScheme(.dark)
}
#endif
