import SwiftUI

/// One non-negotiable card. Unchecked: the signature 1.5 s hold-to-check
/// (HoldToConfirm — ring around the card, progressive haptics; on seal: burst +
/// floating "+X OVR"). Checked: long-press asks before unchecking — exact refund,
/// no burst, no celebration (anti-farming stays in GameStore).
struct ChecklistRowView: View {
    let title: String
    let iconName: String
    let isChecked: Bool
    /// Fired once when the hold completes. Returns the OVR delta actually granted
    /// (nil if the store refused the check) — shown as the floating label.
    let onHoldConfirmed: () -> Double?
    let onUncheckConfirmed: () -> Void

    @State private var showsUncheckDialog = false
    @State private var burstToken = 0
    @State private var sealOpacity: Double = 0
    @State private var floatingDelta: Double?
    @State private var floatOffset: CGFloat = 0
    @State private var floatOpacity: Double = 0

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
    }

    /// Trailing distance to the check-circle center (circle is 26 pt wide).
    private var checkCircleCenterInset: CGFloat { FudoSpacing.cardPadding + 13 }

    var body: some View {
        interactiveCard
            .overlay { sealEcho }
            .overlay(alignment: .trailing) { burst }
            .overlay(alignment: .trailing) { floatingLabel }
            .confirmationDialog("Uncheck this task?", isPresented: $showsUncheckDialog,
                                titleVisibility: .visible) {
                Button("Uncheck", role: .destructive) { onUncheckConfirmed() }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("Points will be taken back.")
            }
    }

    // MARK: - Interaction split (per state)

    @ViewBuilder
    private var interactiveCard: some View {
        if isChecked {
            card
                .onLongPressGesture(minimumDuration: 0.5) { showsUncheckDialog = true }
                .accessibilityAction(named: "Uncheck") { showsUncheckDialog = true }
        } else {
            card
                .holdToConfirm(in: cardShape) { handleHoldConfirmed() }
                .accessibilityAction(named: "Check") { handleHoldConfirmed() }
        }
    }

    /// The hold clock completed — the component already fired the success haptic
    /// and guarantees a single call. Store refusal (nil delta) shows nothing.
    private func handleHoldConfirmed() {
        guard let delta = onHoldConfirmed() else { return }
        burstToken += 1
        sealOpacity = 1
        withAnimation(AppAnimation.standard) { sealOpacity = 0 }
        floatingDelta = delta
        floatOffset = 0
        floatOpacity = 1
        withAnimation(AppAnimation.slow) {
            floatOffset = -36
            floatOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            floatingDelta = nil
        }
    }

    // MARK: - Check effects (row-level so they survive the checked-state flip)

    /// Brief full ring the instant the hold seals — the card restyles to checked
    /// underneath it, so the moment reads as "sealed", not "swapped".
    private var sealEcho: some View {
        cardShape
            .inset(by: HoldToConfirmMetrics.ringWidth / 2)
            .stroke(FudoColor.accent,
                    style: StrokeStyle(lineWidth: HoldToConfirmMetrics.ringWidth, lineCap: .round))
            .opacity(sealOpacity)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var burst: some View {
        if burstToken > 0 {
            ParticleBurstView(color: FudoColor.accent)
                .id(burstToken)
                .offset(x: -checkCircleCenterInset)
        }
    }

    @ViewBuilder
    private var floatingLabel: some View {
        if let delta = floatingDelta {
            Text(String(format: "+%.1f OVR", delta))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(FudoColor.positive)
                .padding(.trailing, FudoSpacing.cardPadding)
                .offset(y: floatOffset)
                .opacity(floatOpacity)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Card

    private var card: some View {
        HStack(spacing: 12) {
            iconTile
            Text(title)
                .font(FudoFont.body())
                .strikethrough(isChecked, color: FudoColor.textSecondary)
                .foregroundStyle(isChecked ? FudoColor.textSecondary : FudoColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            checkCircle
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            cardShape
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
        .opacity(isChecked ? 0.65 : 1)
        .contentShape(cardShape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isChecked ? "Checked" : "Not checked")
    }

    private var iconTile: some View {
        Image(systemName: iconName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(FudoColor.textPrimary)
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                    .fill(FudoColor.bgPrimary)
            }
    }

    private var checkCircle: some View {
        ZStack {
            if isChecked {
                Circle().fill(FudoColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
            } else {
                Circle().strokeBorder(FudoColor.border, lineWidth: 1.5)
            }
        }
        .frame(width: 26, height: 26)
    }
}
