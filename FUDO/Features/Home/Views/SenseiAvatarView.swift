import SwiftUI

/// Small round avatar = head crop of the current rank's sensei (D2 — header, left).
/// The art is a 2:3 full-body render with the head around 19 % from the top, so the
/// crop zooms the fitted image and slides the head into the circle's center. The
/// constants are the plug-in point when real per-rank framing lands.
struct SenseiAvatarView: View {
    let rank: Rank
    var diameter: CGFloat = 34

    /// Zoom applied to the fitted full-body image inside the circle.
    private let headZoom: CGFloat = 3.2
    /// Head center, as a fraction of the art's height from the top.
    private let headCenterY: CGFloat = 0.19

    var body: some View {
        SenseiAssetProvider.image(for: rank)
            .resizable()
            .scaledToFit()
            .frame(height: diameter * headZoom)
            .offset(y: (0.5 - headCenterY) * diameter * headZoom)
            .frame(width: diameter, height: diameter)
            .background(FudoColor.bgCard)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(FudoColor.borderGlass, lineWidth: 0.5)
            }
    }
}
