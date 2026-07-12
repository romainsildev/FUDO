import SwiftUI

/// Single source for motion curves. Slow = premium: nothing faster than 0.4 s
/// is exposed. Always ease-in-out.
enum AppAnimation {
    static let standard = Animation.easeInOut(duration: 0.5)
    static let slow = Animation.easeInOut(duration: 0.6)
}
