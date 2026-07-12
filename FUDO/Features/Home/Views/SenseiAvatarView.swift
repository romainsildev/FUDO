import SwiftUI

/// Small round avatar = head crop of the current rank's sensei (D2 — header, left;
/// also the collapsed hero strip). The pixel-space crop lives in
/// `SenseiAssetProvider.headImage(for:)` — here it just fills the circle.
struct SenseiAvatarView: View {
    let rank: Rank
    var diameter: CGFloat = 34

    var body: some View {
        Group {
            if let head = SenseiAssetProvider.headImage(for: rank) {
                head
                    .resizable()
                    .scaledToFill()
            } else {
                // Missing art — SF Symbol fallback at symbol size, never stretched.
                SenseiAssetProvider.image(for: rank)
                    .resizable()
                    .scaledToFit()
                    .padding(diameter * 0.22)
                    .foregroundStyle(FudoColor.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .background(FudoColor.bgCard)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(FudoColor.borderGlass, lineWidth: 0.5)
        }
    }
}
