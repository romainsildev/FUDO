import SwiftUI

/// App UI type = SF Pro (system). Bebas Neue = ONBOARDING display hooks ONLY — never in app UI.
enum FudoFont {
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold) }
    static func body(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .regular) }

    /// Giant OVR number — monospaced digits so it doesn't jitter while animating.
    static func ovr(_ size: CGFloat = 72) -> Font { .system(size: size, weight: .heavy).monospacedDigit() }

    /// ONBOARDING ONLY. Bebas Neue (PostScript name `BebasNeue-Regular`). Never call from app UI.
    static func onboardingDisplay(_ size: CGFloat = 48) -> Font { .custom("BebasNeue-Regular", size: size) }
}
