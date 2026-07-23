import SwiftUI

/// Three short USP bullets — what he unlocks, never a free/premium comparison
/// table (a documented loser). SF Symbols in vermillon, one line each, naked on
/// the ink background so the screen breathes.
struct PaywallBulletsView: View {
    private struct Bullet: Identifiable {
        let id: Int
        let icon: String
        let text: String
    }

    private let bullets = [
        Bullet(id: 0, icon: "checkmark.seal.fill",
               text: "Your signed protocol, live from day 1."),
        Bullet(id: 1, icon: "chart.line.uptrend.xyaxis",
               text: "OVR + ranks — discipline you can measure."),
        Bullet(id: 2, icon: "apps.iphone",
               text: "Widget + reminders that keep you locked in."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(bullets) { bullet in
                HStack(spacing: 12) {
                    Image(systemName: bullet.icon)
                        .fudoFont(.glyph(17))
                        .foregroundStyle(FudoColor.accent)
                        .frame(width: 26)
                    Text(bullet.text)
                        .fudoFont(.body(15))
                        .foregroundStyle(FudoColor.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
