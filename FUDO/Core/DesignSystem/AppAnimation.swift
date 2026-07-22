import SwiftUI

/// Single source for motion curves. Slow = premium: nothing faster than 0.4 s
/// is exposed. Ease-in-out by default; ONE spring for layout that grows under
/// the finger (report accordion, batch #3) — same tempo, a livelier settle.
enum AppAnimation {
    static let standard = Animation.easeInOut(duration: 0.5)
    static let slow = Animation.easeInOut(duration: 0.6)
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.85)
}
