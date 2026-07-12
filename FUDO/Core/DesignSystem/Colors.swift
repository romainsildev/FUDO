import SwiftUI

/// Design-system color tokens (CLAUDE.md). Never hardcode a hex in a view.
/// Each token must be mirrored in the Asset Catalog under the same name when
/// the widget target is added (widget can't read Swift tokens).
enum FudoColor {
    static let bgPrimary = Color(hex: "121110")   // warm ink black
    static let bgCard = Color(hex: "1C1A17")
    static let border = Color(hex: "2A2724")      // 1px on every card, never a shadow

    static let textPrimary = Color(hex: "FAF0E6") // never pure white
    static let textSecondary = Color(hex: "A89F92")

    static let accent = Color(hex: "E34234")       // vermillon — CTA, rings, flame, ensō, bars
    static let accentPressed = Color(hex: "FF5140")
    static let accentDeep = Color(hex: "7A1F17")   // rank-badge backgrounds

    static let positive = Color(hex: "34C759")     // OVR delta ▲ only
    static let negative = Color(hex: "FF453A")     // OVR delta ▼ only

    static let celebrationGold = Color(hex: "E8B44A") // celebration bursts only
}
