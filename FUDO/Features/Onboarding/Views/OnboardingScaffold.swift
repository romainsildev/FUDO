import SwiftUI

/// The skeleton of every question and value screen: chrome slot, vermillon
/// eyebrow, title, content, one CTA. Ten screens share it, so the rhythm can't
/// drift between two of them. The bar and the chevron are NOT rendered here —
/// they live in `OnboardingChromeHeader` (flow container), outside the slide;
/// the scaffold only reserves their line so the vertical rhythm holds.
///
/// A nil eyebrow AND title hands the whole hierarchy to the content (OB 10's
/// Bebas display headline).
///
/// The CTA is grisé — not hidden — while the answer is missing: he sees where
/// he's going, he just can't get there yet. A live button that does nothing is
/// the pitfall we're avoiding, not a disabled one.
struct OnboardingScaffold<Content: View>: View {
    let step: OnboardingStep
    var eyebrow: String?
    var title: String?
    var subtitle: String?
    var ctaTitle: String = "Continue"
    var canAdvance: Bool
    let onAdvance: () -> Void
    @ViewBuilder let content: () -> Content

    /// The chrome line clears the notch; the eyebrow starts well below it (frames).
    private static var headerTopPadding: CGFloat { 8 }
    private static var eyebrowTopPadding: CGFloat { 56 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — same box the flow-level header draws in.
            Color.clear
                .frame(height: 24)
                .padding(.top, Self.headerTopPadding)

            if let eyebrow {
                Text(eyebrow)
                    .fudoFont(.label(13, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(FudoColor.accent)
                    .padding(.top, Self.eyebrowTopPadding)
            }

            if let title {
                Text(title)
                    .fudoFont(.title(28, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            if let subtitle {
                Text(subtitle)
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 6)
            }

            content()
                .padding(.top, eyebrow == nil && title == nil ? Self.eyebrowTopPadding : 32)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) { cta }
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
