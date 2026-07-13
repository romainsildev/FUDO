import SwiftUI

/// Metrics of the signature hold-to-confirm gesture — single source, no magic
/// numbers in views (CLAUDE.md). The challenge confirmation screen reuses these
/// verbatim (same duration, `.heavy` completion).
enum HoldToConfirmMetrics {
    /// 1.0 s — tuned down from 1.5 s after device runs (2026-07-12 polish pass).
    static let duration: TimeInterval = 1.0
    /// Early release → the ring rewinds smoothly in this time.
    static let rewindDuration: TimeInterval = 0.3
    static let ringWidth: CGFloat = 3
    /// Progressive haptic build during the hold (light → medium → heavy),
    /// evenly spaced before the completion haptic — compresses with `duration`.
    static let hapticStepCount = 3
    static let pressedScale: CGFloat = 0.985
    /// How long the sealed ring lingers before the component resets itself.
    static let sealResetDelay: TimeInterval = 0.6
    /// Short recognition for secondary long-press actions (uncheck → dialog).
    static let quickLongPress: TimeInterval = 0.35
}

/// Haptic fired the instant the hold completes.
enum HoldCompletionHaptic {
    case success   // checklist validation
    case heavy     // heavyweight commitments (challenge confirmation)

    func fire() {
        switch self {
        case .success: Haptics.success()
        case .heavy: Haptics.heavy()
        }
    }
}

/// FUDO's signature interaction: press and hold for `duration` — a vermillon ring
/// draws along `shape` while the haptic builds step by step — then `onConfirm`
/// fires EXACTLY once with the completion haptic. Early release rewinds the ring
/// (no haptic spam, nothing validated).
///
/// Built on a Button so a ScrollView wins instantly: any vertical drag beyond the
/// system slop un-presses the button, which cancels the hold and rewinds the ring
/// while the scroll proceeds. The wall-clock Task is the source of truth for
/// completion; the ring animation only mirrors it.
struct HoldToConfirm<Ring: InsettableShape>: ViewModifier {
    let shape: Ring
    let duration: TimeInterval
    let completionHaptic: HoldCompletionHaptic
    /// Ring stroke color — default vermillon (dark cards); the vermillon CTAs
    /// pass a cream ring so it isn't invisible on their own accent fill.
    var ringColor: Color = FudoColor.accent
    let onConfirm: () -> Void

    @State private var progress: CGFloat = 0
    @State private var ringOpacity: Double = 1
    @State private var sealed = false
    @State private var holdTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        Button(action: {}) { content }
            .buttonStyle(PressDetectorButtonStyle(onPressedChange: handlePress))
            .overlay { ring }
    }

    private var ring: some View {
        shape
            .inset(by: HoldToConfirmMetrics.ringWidth / 2)
            .trim(from: 0, to: progress)
            .stroke(ringColor,
                    style: StrokeStyle(lineWidth: HoldToConfirmMetrics.ringWidth, lineCap: .round))
            .opacity(ringOpacity)
            .allowsHitTesting(false)
    }

    // MARK: - Hold lifecycle

    private func handlePress(_ isPressed: Bool) {
        if isPressed { begin() } else { cancel() }
    }

    private func begin() {
        guard holdTask == nil, !sealed else { return }
        // Restart clean even when re-pressed mid-rewind: the clock below owns
        // completion, so the ring must never be ahead of it.
        withTransaction(Transaction(animation: nil)) {
            progress = 0
            ringOpacity = 1
        }
        withAnimation(.linear(duration: duration)) { progress = 1 }
        holdTask = Task { @MainActor in
            let stepInterval = duration / Double(HoldToConfirmMetrics.hapticStepCount + 1)
            do {
                for step in 1...HoldToConfirmMetrics.hapticStepCount {
                    try await Task.sleep(for: .seconds(stepInterval))
                    fireStepHaptic(step)
                }
                try await Task.sleep(for: .seconds(stepInterval))
            } catch { return }   // released — cancel() owns the rewind, zero extra haptics
            confirm()
        }
    }

    private func cancel() {
        guard !sealed else { return }   // post-confirm release: the seal fade owns cleanup
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: HoldToConfirmMetrics.rewindDuration)) { progress = 0 }
    }

    private func confirm() {
        holdTask = nil
        sealed = true
        completionHaptic.fire()
        onConfirm()
        withAnimation(AppAnimation.standard) { ringOpacity = 0 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(HoldToConfirmMetrics.sealResetDelay))
            withTransaction(Transaction(animation: nil)) {
                progress = 0
                ringOpacity = 1
            }
            sealed = false
        }
    }

    private func fireStepHaptic(_ step: Int) {
        switch step {
        case 1: Haptics.light()
        case 2: Haptics.medium()
        default: Haptics.heavy()
        }
    }
}

/// Exposes the press state to the hold logic; scroll-friendliness comes free from
/// the Button (a drag un-presses it). Subtle sink while held — the ring is the story.
private struct PressDetectorButtonStyle: ButtonStyle {
    let onPressedChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? HoldToConfirmMetrics.pressedScale : 1)
            .animation(AppAnimation.standard, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressedChange(pressed)
            }
    }
}

extension View {
    /// Sugar for ``HoldToConfirm``. Defaults match the checklist card: card-radius
    /// ring, 1.5 s, success haptic. The challenge confirmation passes `.heavy`.
    func holdToConfirm(
        in shape: some InsettableShape = RoundedRectangle(cornerRadius: FudoSpacing.radiusCard,
                                                          style: .continuous),
        duration: TimeInterval = HoldToConfirmMetrics.duration,
        completionHaptic: HoldCompletionHaptic = .success,
        ringColor: Color = FudoColor.accent,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(HoldToConfirm(shape: shape, duration: duration,
                               completionHaptic: completionHaptic, ringColor: ringColor,
                               onConfirm: onConfirm))
    }
}
