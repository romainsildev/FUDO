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
    /// Dimmed, desaturated vermillon — the BAD number (OB 10's starting OVR):
    /// legible, but drained, so OB 13's full-accent projection reads as the
    /// deliverance by contrast. Never for CTAs or live UI accents.
    static let accentMuted = Color(hex: "9A4238")

    static let positive = Color(hex: "34C759")     // OVR delta ▲ only
    static let negative = Color(hex: "FF453A")     // OVR delta ▼ only

    static let celebrationGold = Color(hex: "E8B44A") // celebration bursts + crossed rank thresholds (2026-07-23)

    /// Locked-rank discs on the Progression path — pitch-dark on purpose: future ranks
    /// must be a total mystery (Romain, 2026-07-23), no silhouette hinting at the art.
    static let silhouette = Color(hex: "0B0A09")

    // Glass (RiteOff recipe) — translucent white overlays for `.ultraThinMaterial`
    // capsules/cards. Dark-only, app UI only (never mirrored to the widget's Asset
    // Catalog — the widget renders a flat snapshot, no glass). Not "pure white text":
    // these are frosted-glass tints, applied via opacity, never as a foreground color.
    static let surfaceGlass = Color.white.opacity(0.06)       // default glass tint
    static let surfaceGlassStrong = Color.white.opacity(0.10) // active / raised glass
    /// Dark glass tint for CARDS floating over video (OB 01c): a white tint on a
    /// large glassEffect surface reads washed-grey on device — cards tint toward
    /// the ink instead, matching the near-black card of the frames.
    static let surfaceGlassInk = Color.black.opacity(0.45)
    static let borderGlass = Color.white.opacity(0.22)        // 0.5px glass hairline
    static let specularHighlight = Color.white.opacity(0.18)  // top-edge light catch
}

/// Shared gradients built from the tokens above — never hand-mix hexes in views.
enum FudoGradient {
    /// Flame: vermillon base rising into a gold tip (Romain, 2026-07-12 polish pass).
    /// Used by the streak pill and the flame-sheet hero. NOT a celebration use of
    /// gold — this is the flame's identity color.
    static let flame = LinearGradient(
        colors: [FudoColor.celebrationGold, FudoColor.accent],
        startPoint: .top,
        endPoint: .bottom
    )
}
