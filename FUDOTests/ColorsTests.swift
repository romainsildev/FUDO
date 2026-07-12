import Testing
import SwiftUI
import UIKit
@testable import FUDO

struct ColorsTests {
    private func rgb(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    @Test func hexParsesToComponents() {
        let c = rgb(Color(hex: "E34234"))
        #expect(abs(c.r - 0.890) < 0.01)
        #expect(abs(c.g - 0.259) < 0.01)
        #expect(abs(c.b - 0.204) < 0.01)
    }

    @Test func accentTokenIsVermillon() {
        let a = rgb(FudoColor.accent)
        let hex = rgb(Color(hex: "E34234"))
        #expect(abs(a.r - hex.r) < 0.001)
        #expect(abs(a.g - hex.g) < 0.001)
        #expect(abs(a.b - hex.b) < 0.001)
    }
}
