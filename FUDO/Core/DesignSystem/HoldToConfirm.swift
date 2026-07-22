import CoreHaptics
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

/// How the hold FEELS while the finger is down.
///  - `.steps` (default): three discrete impacts, light → medium → heavy.
///  - `.ramp`: one continuous vibration climbing the whole hold (intensity
///    0.2 → 1.0, sharpness → 0.7) via CHHapticEngine — the OB 17 signature
///    hold. Falls back to the step impacts when the engine isn't available.
enum HoldHapticStyle {
    case steps
    case ramp
}

/// The `.ramp` player. One engine per hold: created on press, stopped on
/// release or completion. `start` returns false when the hardware or the
/// engine can't do it — the caller then falls back to the step impacts.
@MainActor final class HoldHapticRamp {
    private var engine: CHHapticEngine?

    static let startIntensity: Float = 0.2
    static let endIntensity: Float = 1.0
    static let startSharpness: Float = 0.3
    static let endSharpness: Float = 0.7

    func start(duration: TimeInterval) -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                             CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)],
                relativeTime: 0, duration: duration)
            let intensity = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [.init(relativeTime: 0, value: Self.startIntensity),
                                .init(relativeTime: duration, value: Self.endIntensity)],
                relativeTime: 0)
            let sharpness = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [.init(relativeTime: 0, value: Self.startSharpness),
                                .init(relativeTime: duration, value: Self.endSharpness)],
                relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event],
                                              parameterCurves: [intensity, sharpness])
            try engine.makePlayer(with: pattern).start(atTime: 0)
            self.engine = engine
            return true
        } catch {
            return false
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }
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
    /// Stroke width — the card rings keep the 3 pt default; the onboarding's
    /// 148 pt HOLD circle passes a thicker one (3 pt vanishes at that diameter).
    var ringWidth: CGFloat = HoldToConfirmMetrics.ringWidth
    /// Press squeeze. The ring is drawn OUTSIDE the button style, so it never
    /// scales with the content: fine when the ring hugs the whole card, but a
    /// ring anchored on a sub-element (OB 14's check circle) drifts off-centre
    /// under the squeeze — those call sites pass 1.
    var pressedScale: CGFloat = HoldToConfirmMetrics.pressedScale
    /// OB 17's capsule-fill hold draws its own progress: it hides the ring and
    /// mirrors the clock through `onHoldChange` instead.
    var showsRing: Bool = true
    /// `.steps` (default) or `.ramp` — see `HoldHapticStyle`.
    var hapticStyle: HoldHapticStyle = .steps
    /// Mirrors the press: `true` when the hold clock starts, `false` when the
    /// finger releases early. NOT called on completion — `onConfirm` owns that
    /// (the caller's visual is at 100 % by construction).
    var onHoldChange: ((Bool) -> Void)?
    let onConfirm: () -> Void

    @State private var progress: CGFloat = 0
    @State private var ringOpacity: Double = 1
    @State private var sealed = false
    @State private var holdTask: Task<Void, Never>?
    @State private var ramp = HoldHapticRamp()

    func body(content: Content) -> some View {
        Button(action: {}) { content }
            .buttonStyle(PressDetectorButtonStyle(pressedScale: pressedScale,
                                                  onPressedChange: handlePress))
            .overlay { if showsRing { ring } }
    }

    private var ring: some View {
        shape
            .inset(by: ringWidth / 2)
            .trim(from: 0, to: progress)
            .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
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
        onHoldChange?(true)
        // The ramp replaces the step impacts when it starts; when the engine
        // can't (no hardware, DEBUG sim), the steps below are the fallback.
        let rampActive = hapticStyle == .ramp && ramp.start(duration: duration)
        holdTask = Task { @MainActor in
            let stepInterval = duration / Double(HoldToConfirmMetrics.hapticStepCount + 1)
            do {
                for step in 1...HoldToConfirmMetrics.hapticStepCount {
                    try await Task.sleep(for: .seconds(stepInterval))
                    if !rampActive { fireStepHaptic(step) }
                }
                try await Task.sleep(for: .seconds(stepInterval))
            } catch { return }   // released — cancel() owns the rewind, zero extra haptics
            confirm()
        }
    }

    private func cancel() {
        guard !sealed else { return }   // post-confirm release: the seal fade owns cleanup
        ramp.stop()
        guard holdTask != nil else { return }
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: HoldToConfirmMetrics.rewindDuration)) { progress = 0 }
        onHoldChange?(false)
    }

    private func confirm() {
        holdTask = nil
        sealed = true
        ramp.stop()   // the pattern's duration just elapsed — release the engine
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
    let pressedScale: CGFloat
    let onPressedChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(AppAnimation.standard, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressedChange(pressed)
            }
    }
}

extension View {
    /// Sugar for ``HoldToConfirm``. Defaults match the checklist card: card-radius
    /// ring, `HoldToConfirmMetrics.duration`, success haptic. The challenge
    /// confirmation passes `.heavy`; the onboarding's big HOLD ring passes a
    /// thicker `ringWidth`.
    func holdToConfirm(
        in shape: some InsettableShape = RoundedRectangle(cornerRadius: FudoSpacing.radiusCard,
                                                          style: .continuous),
        duration: TimeInterval = HoldToConfirmMetrics.duration,
        completionHaptic: HoldCompletionHaptic = .success,
        ringColor: Color = FudoColor.accent,
        ringWidth: CGFloat = HoldToConfirmMetrics.ringWidth,
        pressedScale: CGFloat = HoldToConfirmMetrics.pressedScale,
        showsRing: Bool = true,
        hapticStyle: HoldHapticStyle = .steps,
        onHoldChange: ((Bool) -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(HoldToConfirm(shape: shape, duration: duration,
                               completionHaptic: completionHaptic, ringColor: ringColor,
                               ringWidth: ringWidth, pressedScale: pressedScale,
                               showsRing: showsRing, hapticStyle: hapticStyle,
                               onHoldChange: onHoldChange, onConfirm: onConfirm))
    }
}
