import SwiftUI

/// Widget-side design tokens. The widget can't reach the app's Swift `FudoColor`
/// tokens, so every color is doubled in THIS target's Asset Catalog under the
/// same name (CLAUDE.md rule) and referenced here — never a raw hex in a view.
/// The app is dark-only; these are the ink-dark values, single universal idiom.
enum WidgetPalette {
    static let bgPrimary = Color("bgPrimary")
    static let bgCard = Color("bgCard")
    static let border = Color("border")
    static let textPrimary = Color("textPrimary")
    static let textSecondary = Color("textSecondary")
    static let accent = Color("accent")
    static let celebrationGold = Color("celebrationGold")

    /// Flame identity gradient (gold tip → vermillon base) — mirror of
    /// `FudoGradient.flame`. Used by the streak flame, not a celebration use of gold.
    static let flame = LinearGradient(
        colors: [celebrationGold, accent],
        startPoint: .top,
        endPoint: .bottom
    )
}
