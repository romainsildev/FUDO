import SwiftUI

/// Full-flow screen 3: recap (duration, rules, exact end date, starting OVR,
/// reminder time) + the assumed rule of failure, sealed with the signature
/// hold gesture — same as the daily check, heavy haptic on completion.
struct LaunchConfirmScreen: View {
    let viewModel: ChallengeSetupViewModel
    let onCommitted: () -> Void

    @State private var reminderTime = Calendar.current
        .startOfDay(for: .now)
        .addingTimeInterval(TimeInterval(ChallengeSetupViewModel.defaultReminderMinutes * 60))

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FudoSpacing.cardPadding) {
                Text("Lock it in")
                    .font(FudoFont.title())
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 16)

                recapCard
                rulesCard
                reminderCard
                failureRule

                Spacer(minLength: 110)
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { commitCTA }
        .navigationTitle("")
        .toolbarBackground(FudoColor.bgPrimary, for: .navigationBar)
    }

    // MARK: - Recap

    private var recapCard: some View {
        VStack(spacing: 12) {
            recapRow("Challenge", viewModel.definition.title)
            recapRow("Duration", "\(viewModel.durationDays) days")
            recapRow("Ends", viewModel.endDate.formatted(date: .abbreviated, time: .omitted))
            recapRow("Starting OVR", "\(viewModel.startingOVR)")
        }
        .padding(FudoSpacing.cardPaddingMajor)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func recapRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(FudoFont.body(15))
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(FudoColor.textPrimary)
        }
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR PROTOCOL")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(FudoColor.textSecondary)
            ForEach(viewModel.enabledRules) { rule in
                HStack(spacing: 10) {
                    Image(systemName: rule.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FudoColor.accent)
                        .frame(width: 22)
                    Text(rule.title)
                        .font(FudoFont.body(15))
                        .foregroundStyle(FudoColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FudoSpacing.cardPaddingMajor)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private var reminderCard: some View {
        HStack {
            Text("Daily reminder")
                .font(FudoFont.body(15))
                .foregroundStyle(FudoColor.textSecondary)
            Spacer()
            DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .onChange(of: reminderTime) { _, time in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                    viewModel.reminderMinutes = (components.hour ?? 7) * 60 + (components.minute ?? 0)
                }
        }
        .padding(.horizontal, FudoSpacing.cardPaddingMajor)
        .frame(height: 60)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private var failureRule: some View {
        Text("Incomplete day = your OVR drops. The challenge goes on. No reset. No excuses.")
            .font(FudoFont.body(15))
            .foregroundStyle(FudoColor.textSecondary)
            .padding(.top, 4)
    }

    // MARK: - Commit

    private var commitCTA: some View {
        Text("Hold to commit.")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(FudoColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: FudoSpacing.ctaHeight)
            .background { Capsule().fill(viewModel.canCommit ? FudoColor.accent : FudoColor.bgCard) }
            .overlay {
                Capsule().strokeBorder(viewModel.canCommit ? Color.clear : FudoColor.border,
                                       lineWidth: 1)
            }
            .holdToConfirm(in: Capsule(), completionHaptic: .heavy) { commit() }
            .disabled(!viewModel.canCommit)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, 12)
            .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
    }

    private func commit() {
        guard viewModel.commit() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(HoldToConfirmMetrics.sealResetDelay))
            onCommitted()
        }
    }
}
