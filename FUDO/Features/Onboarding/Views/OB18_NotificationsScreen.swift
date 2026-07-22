import SwiftUI

/// OB 18 — permission asked AFTER the paywall, when he's already committed, and
/// PRECEDED by a screen of ours that says what he loses by refusing. The iOS
/// popup never shows up naked: we prepared it. Retention lever #2 (the widget
/// is #1).
///
/// Granted → schedules for real, then auto-advances (he said yes; don't make him
/// tap again). Denied → a manual "Continue" and one calm line. No wall, no
/// second ask, no trip to iOS Settings.
struct NotificationsScreen: View {
    let reminderMinutes: Int
    let onAdvance: () -> Void

    @State private var wasDenied = false
    @State private var isRequesting = false
    @State private var revealed = false

    private static let bellSize: CGFloat = 40
    private static let previewStagger: TimeInterval = 0.3

    private var reminderTime: String { OnboardingCopy.clockTime(minutes: reminderMinutes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // No progress bar, no chevron (D6): the bar is done at the contract.
            Image(systemName: "bell")
                .fudoFont(.glyph(Self.bellSize, weight: .light))
                .foregroundStyle(FudoColor.accent)
                .padding(.top, 56)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(revealed ? 1 : 0.9)

            Text("Your daily reminder\nat \(reminderTime).")
                .fudoFont(.title(28, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.top, 28)
                .opacity(revealed ? 1 : 0)

            Text(SocialProofCopy.reminderStake)
                .fudoFont(.body(15, weight: .medium))
                .foregroundStyle(FudoColor.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .opacity(revealed ? 1 : 0)
                .animation(AppAnimation.standard.delay(0.15), value: revealed)

            notificationPreview
                .padding(.top, 40)

            // Only the fallback line survives (batch #10): "iOS will ask next"
            // just repeated what the CTA already says.
            if wasDenied {
                Text("You can turn it on later in Settings.")
                    .fudoFont(.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(.top, 16)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { cta }
        .onAppear { withAnimation(AppAnimation.slow) { revealed = true } }
    }

    /// A real notification, dropping in from the top like one. Day 1, not the
    /// frame's "Day 12": this is HIS first reminder, not a stranger's.
    private var notificationPreview: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FudoColor.bgPrimary)
                Image("enso-100")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("FUDO")
                    .fudoFont(.headline(14))
                    .foregroundStyle(FudoColor.textPrimary)
                HStack(spacing: 4) {
                    Text("Day 1. Your protocol is waiting.")
                        .fudoFont(.body(14))
                        .foregroundStyle(FudoColor.textSecondary)
                    Image(systemName: "flame.fill")
                        .fudoFont(.glyph(12))
                        .foregroundStyle(FudoGradient.flame)
                }
            }
            Spacer(minLength: 0)
        }
        // bgCard, not glass: this is an iOS notification, not a FUDO element.
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : -16)
        .animation(AppAnimation.slow.delay(Self.previewStagger), value: revealed)
    }

    private var cta: some View {
        Button {
            if wasDenied {
                onAdvance()
            } else {
                Task { await requestPermission() }
            }
        } label: {
            Text(wasDenied ? "Continue" : "Enable my reminder")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background {
                    Capsule().fill(wasDenied ? FudoColor.bgCard : FudoColor.accent)
                }
                .overlay {
                    Capsule().strokeBorder(wasDenied ? FudoColor.border : Color.clear,
                                           lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
        .animation(AppAnimation.standard, value: wasDenied)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }

    private func requestPermission() async {
        isRequesting = true
        let granted = await NotificationService.requestAuthorization()
        isRequesting = false
        guard granted else {
            // Already-denied users land here too: requestAuthorization returns
            // false with no popup. Same path, no insisting.
            withAnimation(AppAnimation.standard) { wasDenied = true }
            return
        }
        // The RiteOff bug: their "Allow" scheduled nothing. This one does.
        await NotificationService.scheduleDailyReminder(atMinutes: reminderMinutes)
        #if DEBUG
        await NotificationService.debugDumpPendingReminders()
        #endif
        onAdvance()
    }
}

#if DEBUG
#Preview("OB 18 — notifications") {
    NotificationsScreen(reminderMinutes: 420, onAdvance: {})
        .preferredColorScheme(.dark)
}

/// A later reminder — the title wraps around a longer time string.
#Preview("OB 18 — 6:30 AM reminder") {
    NotificationsScreen(reminderMinutes: 390, onAdvance: {})
        .preferredColorScheme(.dark)
}
#endif
