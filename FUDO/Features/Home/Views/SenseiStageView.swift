import SwiftUI

/// How the sensei carries himself today. The mood is POSTURE, not an event —
/// events (checks, day complete) arrive through the triggers.
enum SenseiMood: Equatable {
    case focused    // normal active-challenge stance
    case slumped    // yesterday closed incomplete — he carries it
    case resting    // no active challenge — dimmed, the dojo waits
}

/// Sensei + day ring, the visual heart of Home. The sensei must feel ALIVE
/// (Duolingo pattern): `pulseTrigger` fires a micro-reaction on every check,
/// `celebrationTrigger` fires the sealed-ring + gold-burst moment. With placeholder
/// art the reactions are scale/aura pulses on the still image — when animated art
/// lands, swap the implementation of `react()`/`celebrate()` and the mood modifier;
/// every call site stays untouched.
/// Choreography of the 100 % day moment — one of the few allowed celebrations.
/// Total ≈ 1.8 s: seal beat → ring burst + reaction → settle. Premium, no confetti rain.
private enum CelebrationMetrics {
    static let sealBeat: TimeInterval = 0.45
    static let burstBeat: TimeInterval = 0.45
    static let settleBeat: TimeInterval = 0.9
    static let ringFlashScale: CGFloat = 1.02
    static let senseiPeakScale: CGFloat = 1.06
}

struct SenseiStageView: View {
    let rank: Rank
    let mood: SenseiMood
    /// 0…1 completion of today. Ignored when `showsRingProgress` is false.
    let progress: Double
    /// false = no-challenge state: empty track, no vermillon arc (frame 01b).
    let showsRingProgress: Bool
    let pulseTrigger: Int
    let celebrationTrigger: Int
    /// Stage geometry — defaults are the original (01b no-challenge) cotes; the
    /// v2 active hero passes compact values from `HomeHeroMetrics`.
    var stageHeight: CGFloat = 340
    var ringDiameter: CGFloat = 292
    var senseiHeight: CGFloat = 318
    /// true = sensei centered in the ring arc (v2 hero); false = original
    /// bottom-anchored stance.
    var centersSensei = false

    @State private var senseiScale: CGFloat = 1
    @State private var auraBoost: Double = 0
    @State private var goldFlash: Double = 0
    @State private var ringFlash: Double = 0
    @State private var ringScale: CGFloat = 1
    @State private var showsBurst = false

    var body: some View {
        ZStack {
            aura
            ring
            sensei
            if showsBurst {
                // Gold + vermillon, emitted FROM the ring — not a center pop.
                ParticleBurstView(colors: [FudoColor.celebrationGold, FudoColor.accent],
                                  particleCount: ParticleBurstMetrics.dayCompleteCount,
                                  distance: 34...72,
                                  particleSize: 3...6,
                                  startDistance: 2,
                                  originRadius: ringDiameter / 2,
                                  animation: AppAnimation.slow)
                    .id(celebrationTrigger)
            }
        }
        .frame(height: stageHeight)
        .frame(maxWidth: .infinity)
        .clipped()   // media never overflows the stage (known-pitfalls list)
        .onChange(of: pulseTrigger) { _, _ in react() }
        .onChange(of: celebrationTrigger) { _, _ in celebrate() }
    }

    // MARK: - Layers

    /// Warm vermillon halo behind the sensei; near-extinct while resting.
    private var aura: some View {
        RadialGradient(colors: [FudoColor.accent.opacity(baseAuraOpacity + auraBoost), .clear],
                       center: .center, startRadius: 20, endRadius: ringDiameter * 0.65)
            .overlay {
                RadialGradient(colors: [FudoColor.celebrationGold.opacity(goldFlash), .clear],
                               center: .center, startRadius: 10, endRadius: ringDiameter * 0.58)
            }
            .animation(AppAnimation.slow, value: mood)
    }

    private var baseAuraOpacity: Double {
        switch mood {
        case .focused: return 0.16
        case .slumped: return 0.08
        case .resting: return 0.05
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(FudoColor.border, lineWidth: FudoSpacing.ringWidth)
            if showsRingProgress {
                if progress >= 1 {
                    // Sealed-day glow — the one place the ring is allowed to bloom.
                    Circle()
                        .stroke(FudoColor.accent.opacity(0.45), lineWidth: FudoSpacing.ringWidth + 4)
                        .blur(radius: 6)
                }
                // Celebration seal flash — brighter, wider, gone after the sequence.
                Circle()
                    .stroke(FudoColor.accentPressed.opacity(ringFlash),
                            lineWidth: FudoSpacing.ringWidth + 3)
                    .blur(radius: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(FudoColor.accent,
                            style: StrokeStyle(lineWidth: FudoSpacing.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .scaleEffect(ringScale)
        .animation(AppAnimation.standard, value: progress)
    }

    private var sensei: some View {
        SenseiAssetProvider.image(for: rank)
            .resizable()
            .scaledToFit()
            .frame(height: senseiHeight)
            .scaleEffect(senseiScale * postureScale, anchor: centersSensei ? .center : .bottom)
            .offset(y: postureOffset)
            .saturation(postureSaturation)
            .opacity(postureOpacity)
            .animation(AppAnimation.slow, value: mood)
            .frame(maxHeight: stageHeight, alignment: centersSensei ? .center : .bottom)
    }

    // MARK: - Posture (placeholder-art hooks — real art swaps pose assets here)

    private var postureScale: CGFloat { mood == .slumped ? 0.97 : 1 }
    private var postureOffset: CGFloat { mood == .slumped ? 5 : 0 }

    private var postureSaturation: Double {
        switch mood {
        case .focused: return 1
        case .slumped: return 0.7
        case .resting: return 0.55
        }
    }

    private var postureOpacity: Double {
        switch mood {
        case .focused: return 1
        case .slumped: return 0.88
        case .resting: return 0.8
        }
    }

    // MARK: - Reactions

    /// Micro-reaction on every check: a slow breath — slight grow + aura swell, then release.
    private func react() {
        withAnimation(AppAnimation.standard, completionCriteria: .logicallyComplete) {
            senseiScale = 1.04
            auraBoost = 0.10
        } completion: {
            withAnimation(AppAnimation.standard) {
                senseiScale = 1
                auraBoost = 0
            }
        }
    }

    /// 100 % day, live only (CelebrationMetrics choreography):
    /// 1. the ring seals — flash + micro scale pulse, medium haptic;
    /// 2. gold+vermillon burst FROM the ring, sensei's big breath, gold aura, success haptic;
    /// 3. everything settles into the steady sealed state (frame 01c).
    private func celebrate() {
        Task { @MainActor in
            withAnimation(AppAnimation.standard) {
                ringFlash = 0.8
                ringScale = CelebrationMetrics.ringFlashScale
            }
            try? await Task.sleep(for: .seconds(CelebrationMetrics.sealBeat))
            Haptics.medium()
            showsBurst = true
            withAnimation(AppAnimation.standard) {
                senseiScale = CelebrationMetrics.senseiPeakScale
                goldFlash = 0.30
                ringScale = 1
            }
            try? await Task.sleep(for: .seconds(CelebrationMetrics.burstBeat))
            Haptics.success()
            withAnimation(AppAnimation.slow) {
                senseiScale = 1
                goldFlash = 0
                ringFlash = 0
            }
            try? await Task.sleep(for: .seconds(CelebrationMetrics.settleBeat))
            showsBurst = false
        }
    }
}
