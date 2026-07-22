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

    /// The title sits high — the steps are the screen, not the heading.
    private static let titleTopFraction: CGFloat = 0.38

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: geometry.size.height * Self.titleTopFraction)

                Text(title)
                    .fudoFont(.title(26, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)

                // OB 12's bullets, verbatim (batch #10 leftover): hollow →
                // accent ring + dots cascade → filled pop. One loader language.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        BuildBullet(text: step, state: bulletState(index),
                                    isFirst: index == 0, isLast: index == steps.count - 1)
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

    private func bulletState(_ index: Int) -> BuildBullet.State {
        if index < completed { return .done }
        return index == completed ? .active : .idle
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

#if DEBUG
/// The step names carry HIS numbers — that's the whole reason the wait works.
#Preview("OB 12 — building your protocol") {
    OnboardingLoaderScreen(
        title: "Building your protocol…",
        steps: ["Reading your weak spot",
                "Calibrating your daily rules",
                "Setting your start — OVR 44",
                "Projecting your 30-day climb"],
        footer: "Locking in your numbers. A few seconds.",
        duration: OnboardingMetrics.buildLoaderDuration,
        onFinished: {})
        .preferredColorScheme(.dark)
}

#Preview("OB 19 — setting up your protocol") {
    OnboardingLoaderScreen(
        title: "Setting up your protocol…",
        steps: ["Saving your protocol",
                "Scheduling your daily reminder",
                "Preparing your dojo",
                "Lighting your streak"],
        footer: "Day 1 starts today. Almost there.",
        duration: OnboardingMetrics.setupLoaderDuration,
        onFinished: {})
        .preferredColorScheme(.dark)
}
#endif
