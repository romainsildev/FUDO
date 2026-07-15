import SwiftUI

/// The skeleton of every question and value screen: bar + back on one line,
/// vermillon eyebrow, title, content, one CTA. Ten screens share it, so the
/// rhythm can't drift between two of them.
///
/// The CTA is grisé — not hidden — while the answer is missing: he sees where
/// he's going, he just can't get there yet. A live button that does nothing is
/// the pitfall we're avoiding, not a disabled one.
struct OnboardingScaffold<Content: View>: View {
    let step: OnboardingStep
    let eyebrow: String
    let title: String
    var subtitle: String?
    var ctaTitle: String = "Continue"
    var canAdvance: Bool
    var onBack: (() -> Void)?
    let onAdvance: () -> Void
    @ViewBuilder let content: () -> Content

    /// The header line clears the notch; the eyebrow starts well below it (frames).
    private static var headerTopPadding: CGFloat { 8 }
    private static var eyebrowTopPadding: CGFloat { 56 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, Self.headerTopPadding)

            Text(eyebrow)
                .fudoFont(.label(13, weight: .bold))
                .kerning(2)
                .foregroundStyle(FudoColor.accent)
                .padding(.top, Self.eyebrowTopPadding)

            Text(title)
                .fudoFont(.title(28, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            if let subtitle {
                Text(subtitle)
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 6)
            }

            content()
                .padding(.top, 32)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) { cta }
    }

    /// Back and the bar share the top line. Without back, the bar takes the full
    /// width — which is exactly what the walls (09, 16, 17) look like.
    private var header: some View {
        HStack(spacing: 12) {
            if step.showsBack, let onBack {
                Button {
                    Haptics.light()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .fudoFont(.headline())
                        .foregroundStyle(FudoColor.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.trailing, 4)
                }
                .buttonStyle(.plain)
            }
            OnboardingProgressBar(fraction: step.progressFraction)
        }
        .frame(height: 24)
    }

    private var cta: some View {
        Button(action: onAdvance) {
            Text(ctaTitle)
                .fudoFont(.headline())
                .foregroundStyle(canAdvance ? FudoColor.textPrimary : FudoColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background {
                    Capsule().fill(canAdvance ? FudoColor.accent : FudoColor.bgCard)
                }
                .overlay {
                    Capsule().strokeBorder(canAdvance ? Color.clear : FudoColor.border,
                                           lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance)
        .animation(AppAnimation.standard, value: canAdvance)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }
}
