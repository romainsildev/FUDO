import CoreGraphics

/// Layout constants (CLAUDE.md). Card corners use `.rect(cornerRadius:style:.continuous)`.
enum FudoSpacing {
    static let screenMargin: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardPaddingMajor: CGFloat = 20
    static let sectionGap: CGFloat = 40
    static let radiusCard: CGFloat = 24
    static let radiusNested: CGFloat = 8
    static let ctaHeight: CGFloat = 56   // primary CTA = Capsule, height 56
    static let ringWidth: CGFloat = 6    // lineCap .round
    /// Breathing room under the last element of a screen. Clearing the TAB BAR is
    /// NOT this value's job: the native TabView already insets its content's safe
    /// area (audit 2026-07-15 — the old 90/100 pt paddings dated from the custom
    /// floating pill and stacked on top of that inset).
    static let contentBottom: CGFloat = 24
}
