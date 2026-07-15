import SwiftUI

/// OB 01c's poster: the product itself, tilted, floating over the dojo doors.
///
/// The values are DEMO values on purpose — no player exists yet (the PlayerState
/// is only created at the signature, OB 17). This card shows a day that works,
/// not his state. Never wire it to the store.
///
/// Glass recipe: `FudoGlassCapsule` is a Capsule, so it can't serve a rounded
/// rect. Same recipe, card shape, one place — never re-mixed inside a screen.
struct ProtocolGlassCard: View {
    /// Reveal the row checks one by one once the card has landed.
    var checksRevealed = 0

    private static let dayNumber = 12
    private static let ovr = 47
    private static let rows: [(icon: String, title: String)] = [
        ("drop.fill", "Cold shower"),
        ("figure.strengthtraining.traditional", "Workout 45 min"),
        ("book.fill", "Read 30 min"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                ruleRow(icon: row.icon, title: row.title, isChecked: index < checksRevealed)
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background { glass }
        .rotationEffect(.degrees(-2.5))
    }

    private var header: some View {
        HStack {
            Text("DAY \(Self.dayNumber)")
                .fudoFont(.label(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                Text("OVR \(Self.ovr)")
                    .fudoFont(.stat(13))
                    .foregroundStyle(FudoColor.accent)
                // The ARROW carries the green — bars and rings stay vermillon.
                Image(systemName: "arrowtriangle.up.fill")
                    .fudoFont(.glyph(9))
                    .foregroundStyle(FudoColor.positive)
            }
        }
    }

    private func ruleRow(icon: String, title: String, isChecked: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .fudoFont(.glyph(15))
                .foregroundStyle(FudoColor.textSecondary)
                .frame(width: 20)
            Text(title)
                .fudoFont(.body(14))
                .foregroundStyle(FudoColor.textPrimary)
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .fill(isChecked ? FudoColor.accent : Color.clear)
                Circle()
                    .strokeBorder(isChecked ? Color.clear : FudoColor.border, lineWidth: 1.5)
                if isChecked {
                    Image(systemName: "checkmark")
                        .fudoFont(.glyph(10, weight: .bold))
                        .foregroundStyle(FudoColor.textPrimary)
                }
            }
            .frame(width: 20, height: 20)
            .animation(AppAnimation.standard, value: isChecked)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    /// The FudoGlassCapsule recipe, card-shaped: material + tint, glass hairline,
    /// top specular catch. No drop shadow — FUDO cards never cast one.
    private var glass: some View {
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
