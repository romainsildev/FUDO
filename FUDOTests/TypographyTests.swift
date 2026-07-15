import SwiftUI
import Testing
import UIKit
@testable import FUDO

struct TypographyTests {
    @Test func bebasNeueIsRegistered() {
        // Host app registers UIAppFonts → the PostScript name must resolve.
        #expect(UIFont(name: "BebasNeue-Regular", size: 17) != nil)
    }

    // MARK: Dynamic Type (audit 2026-07-15)

    /// The acceptance criterion of the typography pass: at the DEFAULT Dynamic Type
    /// setting @ScaledMetric hands back the base value untouched, so every screen
    /// renders at exactly the point size the frames were tuned at.
    @Test func tokensRenderAtTheirDesignSizeAtTheDefaultSetting() {
        #expect(FudoFont.label(10).pointSize(at: 10) == 10)
        #expect(FudoFont.caption(13).pointSize(at: 13) == 13)
        #expect(FudoFont.headline().pointSize(at: 17) == 17)
        #expect(FudoFont.title(34).pointSize(at: 34) == 34)
        #expect(FudoFont.ovr(84).pointSize(at: 84) == 84)
    }

    @Test func textRolesScaleUpToTheTextCap() {
        let body = FudoFont.body(17)
        #expect(body.maxGrowth == FudoFont.textMaxGrowth)
        #expect(body.pointSize(at: 20) == 20)                  // under the cap: passes through
        #expect(body.pointSize(at: 100) == 17 * FudoFont.textMaxGrowth)
    }

    /// Display numerals live inside rings and fixed tiles — tighter leash than text.
    @Test func displayNumeralsTakeTheTighterCap() {
        #expect(FudoFont.ovr(60).pointSize(at: 999) == 60 * FudoFont.numeralMaxGrowth)
        #expect(FudoFont.metric(28).pointSize(at: 999) == 28 * FudoFont.numeralMaxGrowth)
        #expect(FudoFont.numeralMaxGrowth < FudoFont.textMaxGrowth)
    }

    /// A symbol sized from its container (a ring diameter, a fixed frame) is geometry,
    /// not type: it must not move in EITHER direction, whatever the setting.
    @Test func glyphsArePinnedToTheirContainerGeometry() {
        #expect(FudoFont.glyph(24).maxGrowth == 1)
        #expect(FudoFont.glyph(24).pointSize(at: 999) == 24)
        #expect(FudoFont.glyph(24).pointSize(at: 4) == 24)
    }

    /// The giant OVR must never jitter while animating — the numeral roles bake the
    /// monospaced digits in, so no call site has to remember `.monospacedDigit()`.
    @Test func numeralRolesBakeInMonospacedDigits() {
        #expect(FudoFont.stat().usesMonospacedDigits)
        #expect(FudoFont.metric().usesMonospacedDigits)
        #expect(FudoFont.ovr().usesMonospacedDigits)
        #expect(!FudoFont.body().usesMonospacedDigits)
        #expect(!FudoFont.label().usesMonospacedDigits)
    }

    /// Bebas is the onboarding hook and nothing else — every app-UI role is SF Pro.
    @Test func onboardingDisplayIsTheOnlyCustomFamily() {
        #expect(FudoFont.onboardingDisplay().family == "BebasNeue-Regular")
        for token in [FudoFont.title(), .headline(), .body(), .caption(),
                      .label(), .stat(), .metric(), .ovr(), .glyph(12)] {
            #expect(token.family == nil)
        }
    }

    /// Weight defaults are what the old Font factory returned — the migration kept
    /// every call site's rendering identical.
    @Test func roleWeightDefaultsMatchTheOldFontFactory() {
        #expect(FudoFont.title().weight == .bold)
        #expect(FudoFont.body().weight == .regular)
        #expect(FudoFont.caption().weight == .regular)
        #expect(FudoFont.ovr().weight == .heavy)
    }
}
