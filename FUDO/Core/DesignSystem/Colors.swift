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

    // Glass (RiteOff recipe) — translucent white overlays for `.ultraThinMaterial`
    // capsules/cards. Dark-only, app UI only (never mirrored to the widget's Asset
    // Catalog — the widget renders a flat snapshot, no glass). Not "pure white text":
    // these are frosted-glass tints, applied via opacity, never as a foreground color.
    static let surfaceGlass = Color.white.opacity(0.06)       // default glass tint
    static let surfaceGlassStrong = Color.white.opacity(0.10) // active / raised glass
    static let borderGlass = Color.white.opacity(0.22)        // 0.5px glass hairline
    static let specularHighlight = Color.white.opacity(0.18)  // top-edge light catch
}
