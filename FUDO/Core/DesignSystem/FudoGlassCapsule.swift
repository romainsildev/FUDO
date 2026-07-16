import SwiftUI

/// Reusable glass capsule — ONE component, TWO rendering paths:
/// on iOS 26+ the native Liquid Glass (`glassEffect`), earlier the RiteOff
/// `.ultraThinMaterial` recipe. Every capsule call site upgrades for free.
/// Dark-only. Reads over both flat ink (`bgPrimary`) and the warm-gradient screens.
///
/// The Figma mockups use glass capsules app-wide — the floating tab bar, Home
/// pills, cards — so this is the single source of the recipe. Reuse it:
///   `content.padding(…).fudoGlassCapsule()`            // sugar (below)
///   `.background { FudoGlassCapsule() }`                // or drop the shape directly
///
/// Legacy recipe: Capsule ZStack [`.ultraThinMaterial` + tint] · 0.5px `borderGlass`
/// stroke · top specular highlight (masked, non-interactive) · soft drop shadow.
struct FudoGlassCapsule: View {
    /// `true` = `surfaceGlassStrong` tint (raised/active). Default = `surfaceGlass`.
    var strong: Bool = false
    /// Drop the elevation shadow — FUDO cards never cast one (CLAUDE.md).
    var shadow: Bool = true

    var body: some View {
        if #available(iOS 26.0, *) {
            // Native Liquid Glass carries its own depth. NEVER add the legacy drop
            // shadow here: on iOS 26 a `.shadow` on a glassEffect layer rasterizes
            // it with expanded bounds — a huge translucent rounded rect behind the
            // capsule (device bug, 2026-07-12). `shadow` only affects the legacy path.
            Color.clear
                .glassEffect(
                    .regular.tint(strong ? FudoColor.surfaceGlassStrong : FudoColor.surfaceGlass),
                    in: Capsule()
                )
        } else {
            legacyGlass
                .shadow(
                    color: shadow ? .black.opacity(0.40) : .clear,
                    radius: shadow ? 12 : 0,
                    x: 0,
                    y: shadow ? 4 : 0
                )
        }
    }

    private var legacyGlass: some View {
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
    }
}

extension View {
    /// Sets a ``FudoGlassCapsule`` as this view's background — the ergonomic form
    /// for any capsule-shaped content (pills, the tab bar). See the type for the recipe.
    func fudoGlassCapsule(strong: Bool = false, shadow: Bool = true) -> some View {
        background { FudoGlassCapsule(strong: strong, shadow: shadow) }
    }
}

/// The card-shaped sibling of ``FudoGlassCapsule`` — same two rendering paths,
/// same tokens, ONE notch quieter: `.clear` glass instead of `.regular`, because
/// a floating card over video must whisper where a system bar speaks
/// (OB 01c poster card, device pass 2026-07-16). No shadow on either path —
/// FUDO cards never cast one (CLAUDE.md).
struct FudoGlassCard: View {
    var cornerRadius: CGFloat = FudoSpacing.radiusCard

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // NEVER add a `.shadow` to a glassEffect layer (rasterization bug,
            // device 2026-07-12 — see FudoGlassCapsule).
            Color.clear
                .glassEffect(.clear.tint(FudoColor.surfaceGlass), in: shape)
        } else {
            legacyGlass
        }
    }

    /// The FudoGlassCapsule legacy recipe, card-shaped: material + tint, glass
    /// hairline, top specular catch.
    private var legacyGlass: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(FudoColor.surfaceGlass)
        }
        .overlay { shape.strokeBorder(FudoColor.borderGlass, lineWidth: 0.5) }
        .overlay(alignment: .top) {
            LinearGradient(colors: [FudoColor.specularHighlight, .clear],
                           startPoint: .top, endPoint: .center)
                .frame(height: 14)
                .mask { shape }
                .allowsHitTesting(false)
        }
        .clipShape(shape)
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
