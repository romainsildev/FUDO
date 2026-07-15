import SwiftUI

/// OB 12 and OB 19 — the same component, twice.
///
/// The loading IS the beat. There is nothing to load (the app is 100 % local):
/// what this screen really does is give the numbers weight by watching them be
/// "computed", with HIS data in the step names. No spinner, ever.
///
/// `work` is what actually happens behind step 1 — nil on OB 12 (nothing is
/// committed yet), the challenge's creation on OB 19. It must be exactly-once by
/// its own construction: a backgrounded screen replays its `.task`.
struct OnboardingLoaderScreen: View {
    let title: String
    let steps: [String]
    let footer: String
    let duration: TimeInterval
    var work: (() -> Void)?
    let onFinished: () -> Void

    @State private var completed = 0

    private static let dotSize: CGFloat = 14
    /// The title sits high — the steps are the screen, not the heading.
    private static let titleTopFraction: CGFloat = 0.38

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: geometry.size.height * Self.titleTopFraction)

                Text(title)
                    .fudoFont(.title(26, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepRow(step, isDone: index < completed)
                    }
                }
                .padding(.top, 32)

                Spacer()

                Text(footer)
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .onboardingWarmWash()
        .task { await run() }
    }

    private func stepRow(_ label: String, isDone: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(isDone ? FudoColor.accent : Color.clear)
                Circle().strokeBorder(isDone ? Color.clear : FudoColor.border, lineWidth: 1.5)
            }
            .frame(width: Self.dotSize, height: Self.dotSize)

            Text(label)
                .fudoFont(.body(15, weight: .medium))
                .foregroundStyle(isDone ? FudoColor.textPrimary
                                        : FudoColor.textSecondary.opacity(0.6))
        }
        .animation(AppAnimation.standard, value: isDone)
    }

    /// No haptic per step: haptics are for transitions and validations, nowhere
    /// else. The advance at the end carries its own.
    private func run() async {
        work?()
        let interval = duration / Double(max(1, steps.count))
        for _ in steps {
            try? await Task.sleep(for: .seconds(interval))
            withAnimation(AppAnimation.standard) { completed += 1 }
        }
        onFinished()
    }
}
