import SwiftUI

/// Trend indicator. Same rule as the OVR delta: the ARROW carries the green/red,
/// nothing else does. Flat = a neutral right arrow in textSecondary.
struct TrendArrow: View {
    let trend: TrendDirection
    var size: CGFloat = 11

    private var symbol: String {
        switch trend {
        case .up:   "arrowtriangle.up.fill"
        case .down: "arrowtriangle.down.fill"
        case .flat: "arrow.right"
        }
    }

    private var color: Color {
        switch trend {
        case .up:   FudoColor.positive
        case .down: FudoColor.negative
        case .flat: FudoColor.textSecondary
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .accessibilityLabel(trend == .up ? "Trending up" : trend == .down ? "Trending down" : "Steady")
    }
}
