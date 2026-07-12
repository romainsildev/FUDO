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
}
