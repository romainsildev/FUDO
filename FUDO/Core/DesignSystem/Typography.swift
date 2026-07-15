import SwiftUI

/// App UI type = SF Pro (system). Bebas Neue = ONBOARDING display hooks ONLY — never in app UI.
///
/// A token is a ROLE, not a size. It carries the weight, the Dynamic Type anchor and
/// the growth cap; the design's point size stays a parameter. At the DEFAULT Dynamic
/// Type setting a token renders at exactly its point size — the Figma numbers and the
/// device tuning are untouched — and grows from there against `relativeTo`, capped.
///
/// Apply with `.fudoFont(...)`, never `.font(.system(size:))`: a raw system font is
/// frozen at its point size and ignores Dynamic Type entirely. `Font.system(size:)`
/// has no `relativeTo:` — only `@ScaledMetric` (which `.fudoFont` uses) reads the
/// environment, so only it reacts when the user changes the setting.
struct FudoFont {
    /// Growth caps (Romain, 2026-07-15). CONTAINER geometry is fixed — the 112 pt hero
    /// card, the 56 pt CTA, the 44 pt chips, the rings. Only text scales, and only this
    /// far, or it overflows them. Tightened from 1.6 after a device pass at the
    /// accessibility sizes: 1.6 still crowded the 56 pt rows.
    /// NOTE: these reach FUDO's own text only. System chrome (tab bar labels, nav
    /// titles, alerts, DatePicker) is drawn by UIKit and scales uncapped — the only
    /// lever there is `.dynamicTypeSize(...)` on an ancestor.
    static let textMaxGrowth: CGFloat = 1.35
    /// Display numerals live inside rings and fixed tiles: tighter leash.
    static let numeralMaxGrowth: CGFloat = 1.15

    let size: CGFloat
    let weight: Font.Weight
    /// The text style whose Dynamic Type curve this role follows.
    let relativeTo: Font.TextStyle
    /// Cap as a multiple of `size`. 1 = pinned, never scales.
    let maxGrowth: CGFloat
    let usesMonospacedDigits: Bool
    /// nil = SF Pro (the system face). Set only for the Bebas onboarding hooks.
    let family: String?
}

// MARK: - Roles

extension FudoFont {
    private init(_ size: CGFloat, _ weight: Font.Weight, _ relativeTo: Font.TextStyle,
                 maxGrowth: CGFloat = FudoFont.textMaxGrowth,
                 monospacedDigits: Bool = false, family: String? = nil) {
        self.init(size: size, weight: weight, relativeTo: relativeTo, maxGrowth: maxGrowth,
                  usesMonospacedDigits: monospacedDigits, family: family)
    }

    /// Screen titles and hero copy.
    static func title(_ size: CGFloat = 28, weight: Font.Weight = .bold) -> Self {
        Self(size, weight, .title)
    }

    /// CTAs, section headers, row titles — the semibold 17 of the frames.
    static func headline(_ size: CGFloat = 17, weight: Font.Weight = .semibold) -> Self {
        Self(size, weight, .headline)
    }

    /// Running copy.
    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Self {
        Self(size, weight, .body)
    }

    /// Secondary copy — dates, sub-labels, hints.
    static func caption(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Self {
        Self(size, weight, .footnote)
    }

    /// The kerned uppercase eyebrows: "RANK", "TODAY", "TODAY'S PROTOCOL", "DEBUG".
    static func label(_ size: CGFloat = 11, weight: Font.Weight = .semibold) -> Self {
        Self(size, weight, .caption2)
    }

    /// Inline numerals that must not jitter while animating — counters, deltas, "3 / 5".
    static func stat(_ size: CGFloat = 13, weight: Font.Weight = .bold) -> Self {
        Self(size, weight, .footnote, monospacedDigits: true)
    }

    /// Big card numerals — tile values, the streak count. Display type in fixed tiles,
    /// so it takes the tighter cap.
    static func metric(_ size: CGFloat = 28, weight: Font.Weight = .heavy) -> Self {
        Self(size, weight, .title, maxGrowth: numeralMaxGrowth, monospacedDigits: true)
    }

    /// The giant OVR — biggest number on screen, always centred in ring geometry.
    static func ovr(_ size: CGFloat = 72) -> Self {
        Self(size, .heavy, .largeTitle, maxGrowth: numeralMaxGrowth, monospacedDigits: true)
    }

    /// An SF Symbol sized from its own container — a ring diameter, a fixed frame, a
    /// caller-passed size. PINNED: this is geometry, not type. Scaling it would break
    /// the shape it sits in.
    static func glyph(_ size: CGFloat, weight: Font.Weight = .regular) -> Self {
        Self(size, weight, .body, maxGrowth: 1)
    }

    /// ONBOARDING ONLY. Bebas Neue (PostScript name `BebasNeue-Regular`). Never call from app UI.
    static func onboardingDisplay(_ size: CGFloat = 48) -> Self {
        Self(size, .regular, .largeTitle, family: "BebasNeue-Regular")
    }
}

// MARK: - Resolution

extension FudoFont {
    /// The point size this role actually renders at. `scaled` is what @ScaledMetric
    /// made of `size` for the current Dynamic Type setting — at the DEFAULT setting it
    /// IS `size`, so the UI does not move.
    func pointSize(at scaled: CGFloat) -> CGFloat {
        maxGrowth <= 1 ? size : min(scaled, size * maxGrowth)
    }

    func resolved(at scaled: CGFloat) -> Font {
        let point = pointSize(at: scaled)
        guard let family else {
            let font = Font.system(size: point, weight: weight)
            return usesMonospacedDigits ? font.monospacedDigit() : font
        }
        // fixedSize: @ScaledMetric already scaled it — `relativeTo:` would scale twice.
        return .custom(family, fixedSize: point)
    }
}

extension View {
    /// The ONE way to set type in FUDO — carries Dynamic Type with it.
    func fudoFont(_ token: FudoFont) -> some View {
        modifier(FudoFontModifier(token))
    }
}

/// @ScaledMetric is the only mechanism that both keeps an arbitrary point size and
/// reacts to the setting: it reads `\.dynamicTypeSize` from the environment, so the
/// modifier re-resolves whenever that changes. A `Font` value computed by a parent's
/// body cannot — the parent never re-evaluates.
private struct FudoFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let token: FudoFont

    init(_ token: FudoFont) {
        self.token = token
        _scaledSize = ScaledMetric(wrappedValue: token.size, relativeTo: token.relativeTo)
    }

    func body(content: Content) -> some View {
        content.font(token.resolved(at: scaledSize))
    }
}
