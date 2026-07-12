import Testing
import CoreGraphics
@testable import FUDO

struct DesignConstantsTests {
    @Test func spacingTokens() {
        #expect(FudoSpacing.screenMargin == 20)
        #expect(FudoSpacing.cardPadding == 16)
        #expect(FudoSpacing.cardPaddingMajor == 20)
        #expect(FudoSpacing.sectionGap == 40)
        #expect(FudoSpacing.radiusCard == 24)
        #expect(FudoSpacing.radiusNested == 8)
        #expect(FudoSpacing.ctaHeight == 56)
        #expect(FudoSpacing.ringWidth == 6)
    }
}
