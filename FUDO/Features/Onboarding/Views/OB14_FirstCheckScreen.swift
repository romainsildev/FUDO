import SwiftUI

/// OB 14 (S5d recut) — the only screen where his HAND learns something, and it
/// learns it on the REAL component: a Task Row, the same anatomy as the Home
/// checklist (icon tile · title · check circle), the same 1.0 s HoldToConfirm
/// (same clock, same progressive haptics — zero relearning at the Home). One
/// idea on screen: the row, alone, centered. No visible CTA until the gesture
/// is done — the check is the only way forward.
///
/// The progress ring draws around the CHECK CIRCLE, not the card: HoldToConfirm
/// takes any InsettableShape, so `CheckCircleRing` anchors the ring on the
/// coche while the press target stays the whole row. The gesture engine is
/// untouched — no reinvented hold.
///
/// ⚠️ Still a DEMO. The challenge does not exist yet (born at OB 19): nothing
/// calls `store.checkTask`, no OVR moves, no streak is written, and the row
/// can NOT be unchecked (one-way — the Home teaches the undo, not this).
/// Wiring a real check here would hand him a free delta and break the
/// anti-farming pool — do not "finish" this screen.
struct FirstCheckScreen: View {
    let onAdvance: () -> Void
    /// DEBUG previews only — renders the post-check resting state (flame + CTA).
    var startsSealed = false

    @State private var hasSealed = false
    @State private var revealed = false
    @State private var hintPulsing = false
    @State private var showsFlame = false
    @State private var showsCTA = false
    @State private var burstToken = 0
    @State private var sealOpacity: Double = 0

    /// Seal → burst settles → flame lights → CTA slides up. Each step waits for
    /// the previous one to land; the whole beat stays under 2 s.
    private static let flameDelay: TimeInterval = 0.45
    private static let ctaDelay: TimeInterval = 0.55
    private static let rowRevealDelay: TimeInterval = 0.2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chrome slot — the bar renders at flow level, outside the slide.
            Color.clear
                .frame(height: 24)
                .padding(.top, 8)

            Text("Your first rep.")
                .fudoFont(.title(28, weight: .bold))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.top, 56)
                .opacity(revealed ? 1 : 0)

            Spacer(minLength: 0)

            // THE row — alone, centered, generous. The screen is the row.
            checkRow
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 12)

            hint
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            flame
                .frame(maxWidth: .infinity)
                .padding(.top, 26)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) { cta }
        .onboardingWarmWash(.bottom)
        .onAppear { runIntro() }
    }

    // MARK: - The row

    @ViewBuilder private var checkRow: some View {
        let row = FirstCheckRow(isChecked: hasSealed)
            .overlay { sealEcho }
            .overlay(alignment: .trailing) { burst }
            .accessibilityElement(children: .combine)
            .accessibilityValue(hasSealed ? "Checked" : "Not checked")

        if hasSealed {
            row   // one-way demo: no uncheck path, the sealed row is inert
        } else {
            // pressedScale 1: the ring overlay never scales with the button
            // content, so the default squeeze slid the coche ~2 pt off the
            // ring's centre mid-hold (device, batch #8). No squeeze → ring and
            // coche share one immobile centre for the whole hold.
            row
                .holdToConfirm(in: FirstCheckRow.checkRingShape, pressedScale: 1) { seal() }
                .accessibilityAction(named: "Check") { seal() }
        }
    }

    /// Brief full ring around the coche the instant the hold seals — the row
    /// restyles to checked underneath it (same trick as the Home row: the
    /// moment reads as "sealed", not "swapped").
    private var sealEcho: some View {
        FirstCheckRow.checkRingShape
            .inset(by: HoldToConfirmMetrics.ringWidth / 2)
            .stroke(FudoColor.accent,
                    style: StrokeStyle(lineWidth: HoldToConfirmMetrics.ringWidth, lineCap: .round))
            .opacity(sealOpacity)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var burst: some View {
        if burstToken > 0 {
            // From the check circle, like the Home row — not a centre pop.
            ParticleBurstView(color: FudoColor.accent)
                .id(burstToken)
                .offset(x: -FirstCheckRow.checkCenterInset)
        }
    }

    // MARK: - Around the row

    private var hint: some View {
        Text("Hold to check")
            .fudoFont(.caption(13))
            .foregroundStyle(FudoColor.textSecondary)
            // Breathes until he holds — he should understand without reading.
            .opacity(hasSealed ? 0 : (hintPulsing ? 1 : 0.55))
            .animation(AppAnimation.standard, value: hasSealed)
    }

    private var flame: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(FudoGradient.flame)
            Text("Day 0 — streak ignited")
                .foregroundStyle(FudoColor.celebrationGold)
        }
        .fudoFont(.stat(15))
        .opacity(showsFlame ? 1 : 0)
        .offset(y: showsFlame ? 0 : 10)
    }

    /// Hidden until the gesture is done — appearing is its slide-up. The check
    /// is the only unlock; there is no way to skip the rep.
    private var cta: some View {
        Button(action: onAdvance) {
            Text("Continue")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(FudoColor.accent) }
        }
        .buttonStyle(.plain)
        .opacity(showsCTA ? 1 : 0)
        .offset(y: showsCTA ? 0 : 24)
        .allowsHitTesting(showsCTA)
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, 12)
    }

    // MARK: - Sequence

    private func runIntro() {
        if startsSealed {
            revealed = true
            hasSealed = true
            showsFlame = true
            showsCTA = true
            return
        }
        withAnimation(AppAnimation.standard.delay(Self.rowRevealDelay)) { revealed = true }
        withAnimation(.easeInOut(duration: OnboardingMetrics.hintPulse)
            .repeatForever(autoreverses: true)) {
            hintPulsing = true
        }
    }

    /// HoldToConfirm fires the success haptic and guarantees one call per hold,
    /// but it re-arms after its seal delay — the guard keeps a second hold from
    /// replaying the sequence.
    private func seal() {
        guard !hasSealed else { return }
        // The one-and-only real hold-to-check of the demo (no store mutation).
        Analytics.track(AnalyticsEvent.onboardingFirstCheckDone)
        withAnimation(AppAnimation.standard) { hasSealed = true }
        burstToken += 1
        sealOpacity = 1
        withAnimation(AppAnimation.standard) { sealOpacity = 0 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.flameDelay))
            Haptics.medium()
            withAnimation(AppAnimation.standard) { showsFlame = true }
            try? await Task.sleep(for: .seconds(Self.ctaDelay))
            withAnimation(.easeOut(duration: 0.5)) { showsCTA = true }
        }
    }
}

// MARK: - The demo row

/// The Home checklist row's anatomy, replicated for the demo (the real
/// `ChecklistRowView` carries live-store contracts — delta return, uncheck
/// dialog — that this one-way demo must not expose). Same icon tile, same
/// 26 pt check circle, same checked restyle: what his hand learns here is
/// exactly what the Home hands him at day 1.
private struct FirstCheckRow: View {
    let isChecked: Bool

    /// The ring slot: coche AND hold ring share this square — one frame, one
    /// centre, zero asymmetric padding (batch #8 device fix). The ring's
    /// geometry derives from these two constants ONLY.
    static let slotSize: CGFloat = 44
    /// Trailing padding sized so the 26 pt coche sits exactly where the major
    /// card padding used to put it: cardPaddingMajor − (slot − circle) / 2.
    static var slotTrailingPadding: CGFloat { FudoSpacing.cardPaddingMajor - (slotSize - 26) / 2 }
    /// Trailing distance to the slot (= coche = ring) centre.
    static var checkCenterInset: CGFloat { slotTrailingPadding + slotSize / 2 }
    /// The hold ring, concentric with the coche — radius 20 fits the slot.
    static var checkRingShape: CheckCircleRing {
        CheckCircleRing(centerTrailingInset: checkCenterInset, radius: 20)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .fudoFont(.glyph(15, weight: .medium))
                .foregroundStyle(FudoColor.textPrimary)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                        .fill(FudoColor.bgPrimary)
                }

            Text("I started my Monk Mode")
                .fudoFont(.body())
                .strikethrough(isChecked, color: FudoColor.textSecondary)
                .foregroundStyle(isChecked ? FudoColor.textSecondary : FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            ZStack {
                checkCircle
            }
            .frame(width: Self.slotSize, height: Self.slotSize)
        }
        .padding(.leading, FudoSpacing.cardPaddingMajor)
        .padding(.trailing, Self.slotTrailingPadding)
        .padding(.vertical, FudoSpacing.cardPaddingMajor)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
        .opacity(isChecked ? 0.65 : 1)
        .contentShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
        .accessibilityLabel("I started my Monk Mode")
    }

    private var checkCircle: some View {
        ZStack {
            if isChecked {
                Circle().fill(FudoColor.accent)
                Image(systemName: "checkmark")
                    .fudoFont(.glyph(12, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
            } else {
                Circle().strokeBorder(FudoColor.border, lineWidth: 1.5)
            }
        }
        .frame(width: 26, height: 26)
    }
}

/// A ring anchored on the row's check circle: HoldToConfirm strokes and trims
/// whatever InsettableShape it's given, so this is all it takes to draw the
/// hold progress around the coche while the press target stays the whole row.
/// Trim starts at 12 o'clock, clockwise — same read as every FUDO ring.
private struct CheckCircleRing: InsettableShape {
    let centerTrailingInset: CGFloat
    let radius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> CheckCircleRing {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.maxX - centerTrailingInset, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: max(radius - insetAmount, 1),
                    startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
        return path
    }
}

#if DEBUG
/// The hold itself only exists under a finger — the resting state shows the
/// row + pulsing hint; the gesture feel is a device check.
#Preview("OB 14 — before the check") {
    OnboardingPreviewChrome {
        FirstCheckScreen(onAdvance: {})
    }
}

/// Mid-hold, faked statically: the ring drawn at 60 % around the coche —
/// geometry check for the CheckCircleRing anchor.
#Preview("OB 14 — mid-hold (static)") {
    OnboardingPreviewChrome {
        FirstCheckRow(isChecked: false)
            .overlay {
                FirstCheckRow.checkRingShape
                    .inset(by: HoldToConfirmMetrics.ringWidth / 2)
                    .trim(from: 0, to: 0.6)
                    .stroke(FudoColor.accent,
                            style: StrokeStyle(lineWidth: HoldToConfirmMetrics.ringWidth,
                                               lineCap: .round))
            }
            .padding(FudoSpacing.screenMargin)
    }
}

/// Post-check resting state: sealed row, flame lit, CTA up.
#Preview("OB 14 — after the check") {
    OnboardingPreviewChrome {
        FirstCheckScreen(onAdvance: {}, startsSealed: true)
    }
}
#endif
