import SwiftUI

/// Reusable frosted-glass capsule (RiteOff recipe), iOS 17 `.ultraThinMaterial`.
/// Dark-only. Reads over both flat ink (`bgPrimary`) and the warm-gradient screens.
///
/// The Figma mockups use glass capsules app-wide — the floating tab bar, Home
/// pills, cards — so this is the single source of the recipe. Reuse it:
///   `content.padding(…).fudoGlassCapsule()`            // sugar (below)
///   `.background { FudoGlassCapsule() }`                // or drop the shape directly
///
/// Recipe: Capsule ZStack [`.ultraThinMaterial` + tint] · 0.5px `borderGlass`
/// stroke · top specular highlight (masked, non-interactive) · soft drop shadow.
/// iOS 17 APIs only — no iOS 26 `glassEffect`.
struct FudoGlassCapsule: View {
    /// `true` = `surfaceGlassStrong` tint (raised/active). Default = `surfaceGlass`.
    var strong: Bool = false
    /// Drop the elevation shadow — FUDO cards never cast one (CLAUDE.md).
    var shadow: Bool = true

    var body: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(strong ? FudoColor.surfaceGlassStrong : FudoColor.surfaceGlass)
        }
        .overlay {
            Capsule().strokeBorder(FudoColor.borderGlass, lineWidth: 0.5)
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [FudoColor.specularHighlight, .clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 14)
            .mask { Capsule() }
            .allowsHitTesting(false)
        }
        .clipShape(Capsule())
        .shadow(
            color: shadow ? .black.opacity(0.40) : .clear,
            radius: shadow ? 12 : 0,
            x: 0,
            y: shadow ? 4 : 0
        )
    }
}

extension View {
    /// Sets a ``FudoGlassCapsule`` as this view's background — the ergonomic form
    /// for any capsule-shaped content (pills, the tab bar). See the type for the recipe.
    func fudoGlassCapsule(strong: Bool = false, shadow: Bool = true) -> some View {
        background { FudoGlassCapsule(strong: strong, shadow: shadow) }
    }
}

#Preview {
    ZStack {
        FudoColor.bgPrimary.ignoresSafeArea()
        VStack(spacing: 24) {
            Text("Glass pill")
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .fudoGlassCapsule()
            Text("Strong · no shadow")
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .fudoGlassCapsule(strong: true, shadow: false)
        }
    }
}
