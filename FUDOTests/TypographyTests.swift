import Testing
import UIKit
@testable import FUDO

struct TypographyTests {
    @Test func bebasNeueIsRegistered() {
        // Host app registers UIAppFonts → the PostScript name must resolve.
        #expect(UIFont(name: "BebasNeue-Regular", size: 17) != nil)
    }
}
