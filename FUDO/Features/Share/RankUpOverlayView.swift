import SwiftUI

/// Rank-up celebration — a ROOT-LEVEL OVERLAY (not a cover): it plays over the
/// current screen, above the TabView, with Home darkened + blurred behind (a
/// scrim + material, never an opaque screen — the context stays visible). Two
/// beats:
///   1. the rank you're LEAVING in scene, "RANK UP", a line, one CTA "Rank up";
///   2. on tap, a slow CHARGE → RELEASE transformation into the rank you REACHED
///      — the sensei contracts and the world dims (held breath / suspense), then
///      blooms open: smooth swell, glow floods, art crossfades, one restrained
///      gold + vermillon burst (a milestone confetti moment) — then the new
///      rank's name, a discreet share, and dismiss. Deliberately slow and clean:
///      few moving parts, tension over flash.
///
/// Driven by `GameStore.pendingRankUp` (the reached rank, D6 high-water). The
/// end-of-challenge sequence subsumes any rank-up crossed on the final closure
/// (S11) — RootView's presenting gate never shows this while a completion is
/// pending. Analytics: `rank_up_shown` on appear, `rank_up_shared` on share.
struct RankUpOverlayView: View {
    /// The rank just reached (`pendingRankUp`). Beat 2 lands on this.
    let reachedRank: Rank
    let store: GameStore
    let onClose: () -> Void

    private enum Beat { case intro, charging, blooming, revealed }

    @State private var beat: Beat = .intro
    @State private var appeared = false
    @State private var showReached = false      // crossfade leaving → reached art
    @State private var senseiScale: CGFloat = 1 // contract on charge, swell on bloom
    @State private var glowLevel: Double = 0.55 // gathers-then-floods light
    @State private var tensionDim: Double = 0   // extra "held breath" darkening
    @State private var burstTick = 0            // fires the bloom burst
    @State private var shareRequest: ShareCardRequest?

    // Device-tunable knobs — kept here so Romain can pace/size on device.
    private enum Metrics {
        static let senseiHeight: CGFloat = 360     // bigger character
        static let chargeScale: CGFloat = 0.9      // contraction depth
        static let appear = AppAnimation.slow                        // 0.6 fade in
        static let charge = Animation.easeInOut(duration: 0.85)      // slow tension pull
        static let bloom  = Animation.easeInOut(duration: 1.1)       // slow release
        static let reveal = Animation.easeInOut(duration: 0.55)      // name settles in
    }

    /// Three lines in the spirit of "Small steps create big paths." — Romain picks
    /// the one that lands on device by flipping `quoteIndex` (0 / 1 / 2).
    private static let quotes = [
        "Small steps carve the deepest paths.",
        "You showed up. The rank followed.",
        "Discipline is the only shortcut.",
    ]
    private static let quoteIndex = 0

    /// The rank you're LEAVING → the rank you REACHED. In the real flow `reached`
    /// is ≥ Disciple (you never rank up into Novice), so `leaving = reached − 1`
    /// always exists. The DEBUG trigger on a fresh Novice player has no lower rank
    /// → animate UP into the next one instead, so the transformation is always
    /// visible on device.
    private var pair: (leaving: Rank, reached: Rank) {
        if let lower = Rank(rawValue: reachedRank.rawValue - 1) {
            return (lower, reachedRank)
        }
        let up = Rank(rawValue: reachedRank.rawValue + 1) ?? reachedRank
        return (reachedRank, up)
    }

    private var showBurst: Bool { beat == .blooming || beat == .revealed }

    var body: some View {
        ZStack {
            backdrop
            glow
            content
        }
        .shareCardPreview($shareRequest)
        .onAppear(perform: play)
    }

    // MARK: - Backdrop (blur + scrim, Home visible behind)

    /// Material blurs the Home behind; the scrim darkens it; `tensionDim` deepens
    /// that darkness during the charge (the room holds its breath). All layers
    /// absorb every touch — no tap-through, no tap-to-dismiss (the CTA is the only
    /// exit out of beat 1).
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            FudoColor.bgPrimary.opacity(0.62)
            Color.black.opacity(tensionDim)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            eyebrow
            senseiStage
                .padding(.top, 10)
            lowerContent
                .padding(.top, 18)
            Spacer(minLength: 20)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .padding(.bottom, FudoSpacing.contentBottom)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
    }

    private var eyebrow: some View {
        Text("RANK UP")
            .fudoFont(.label(15, weight: .heavy))
            .kerning(6)
            .foregroundStyle(FudoColor.celebrationGold)
    }

    // Sensei art — big, and the only thing that moves during the transform. The
    // leaving rank crossfades into the reached rank on the bloom; a slow contract
    // then swell (no bounce, no flash) carries the tension.
    private var senseiStage: some View {
        ZStack {
            SenseiAssetProvider.image(for: pair.leaving)
                .resizable()
                .scaledToFit()
                .opacity(showReached ? 0 : 1)
            SenseiAssetProvider.image(for: pair.reached)
                .resizable()
                .scaledToFit()
                .opacity(showReached ? 1 : 0)
        }
        .frame(height: Metrics.senseiHeight)
        .scaleEffect(senseiScale)
        .overlay {
            if showBurst {
                burst.id(burstTick)
            }
        }
        .accessibilityLabel(beat == .revealed ? "\(pair.reached.displayName) sensei" : "Rank up")
    }

    /// One restrained burst at the bloom peak — gold + vermillon from the centre,
    /// slow and generous. Milestone confetti only.
    private var burst: some View {
        ZStack {
            GoldBurstView()
            ParticleBurstView(color: FudoColor.accent,
                              particleCount: ParticleBurstMetrics.celebrationCount,
                              distance: 100...160,
                              particleSize: 3...5,
                              startDistance: 16,
                              animation: AppAnimation.slow)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var lowerContent: some View {
        switch beat {
        case .intro:
            introControls
                .transition(.opacity)
        case .charging, .blooming:
            // Nothing under the sensei during the transform — the eye stays on it.
            Color.clear.frame(height: 1)
        case .revealed:
            revealControls
                .transition(.opacity)
        }
    }

    private var introControls: some View {
        VStack(spacing: 24) {
            Text(Self.quotes[Self.quoteIndex])
                .fudoFont(.title(22, weight: .semibold))
                .foregroundStyle(FudoColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: beginTransform) {
                Text("Rank up")
                    .fudoFont(.headline(17, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background(Capsule().fill(FudoColor.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var revealControls: some View {
        VStack(spacing: 0) {
            Text(pair.reached.displayName.uppercased())
                .fudoFont(.title(50, weight: .heavy))
                .kerning(2)
                .foregroundStyle(FudoColor.accent)
            Text("OVR \(store.player?.displayedOVR ?? Int(pair.reached.floorOVR))")
                .fudoFont(.metric(22))
                .kerning(2)
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.top, 6)
            Text("You've reached \(pair.reached.displayName). Keep the fire.")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 40)
            revealActions
                .padding(.top, 26)
        }
    }

    /// Beat 2 exits: a DISCREET outline share (not the loud vermillon fill) + Done.
    private var revealActions: some View {
        VStack(spacing: 12) {
            Button(action: share) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .fudoFont(.headline(15, weight: .semibold))
                    Text("Share")
                        .fudoFont(.headline(16))
                }
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().stroke(FudoColor.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                onClose()
            } label: {
                Text("Done")
                    .fudoFont(.headline(16))
                    .foregroundStyle(FudoColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    /// Gold + vermillon halo — dims to a tense low during the charge, floods on the
    /// bloom. `glowLevel` is animated by the choreography, so no implicit modifier.
    private var glow: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accentDeep.opacity(0.42), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 340)
            RadialGradient(colors: [FudoColor.celebrationGold.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.40), startRadius: 10, endRadius: 260)
        }
        .blur(radius: 34)
        .opacity(glowLevel)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Choreography

    private func play() {
        guard !appeared else { return }
        withAnimation(Metrics.appear) { appeared = true }
        Haptics.medium()
        // The celebration was seen (plan §1.8) — once per rank (high-water gated
        // upstream; `play` runs once per presentation). Keyed on the reached rank,
        // matching the store's `rank_up` crossing event.
        Analytics.track(AnalyticsEvent.rankUpShown, ["rank": reachedRank.displayName.lowercased()])
    }

    /// Beat 1 → 2, in three chained steps (no manual delay sequencing — each stage
    /// starts from the previous animation's completion):
    ///   CHARGE  — contract + dim + darken the room (suspense).
    ///   BLOOM   — swell back, flood the glow, crossfade the art, fire the burst.
    ///   REVEAL  — the new rank's name settles in.
    private func beginTransform() {
        guard beat == .intro else { return }
        Haptics.rigid()
        withAnimation(Metrics.charge) {
            beat = .charging
            senseiScale = Metrics.chargeScale
            glowLevel = 0.30
            tensionDim = 0.30
        } completion: {
            Haptics.heavy()
            burstTick += 1
            withAnimation(Metrics.bloom) {
                beat = .blooming
                showReached = true
                senseiScale = 1
                glowLevel = 1
                tensionDim = 0
            } completion: {
                withAnimation(Metrics.reveal) { beat = .revealed }
                Haptics.success()
            }
        }
    }

    private func share() {
        Haptics.medium()
        // Share INTENT from the overlay (plan §1.8) — distinct from the actual
        // completed share, which `share_card_shared {origin: rank_up}` reports.
        Analytics.track(AnalyticsEvent.rankUpShared, ["rank": pair.reached.displayName.lowercased()])
        shareRequest = ShareCardRequest(
            variant: .rankUp,
            data: ShareCardData.rankUp(to: pair.reached, from: store),
            origin: .rankUp)
    }
}

#if DEBUG
import SwiftData

/// ONE in-memory container on the shared FudoSchema (SwiftData multi-container
/// pitfall 2026-07-12), seeded with the debug dataset — retained in a `static let`
/// so its context is never reset (canvas crash 2026-07-15).
@MainActor
private enum RankUpOverlayPreviewFactory {
    static let container: ModelContainer? = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let built = try ModelContainer(for: FudoSchema.schema, configurations: config)
            DebugSeed.seed(context: built.mainContext)
            return built
        } catch {
            return nil
        }
    }()

    static let store: GameStore? = container.map { GameStore(modelContext: $0.mainContext) }
}

#Preview("Rank-up overlay — Warrior") {
    if let store = RankUpOverlayPreviewFactory.store {
        // Faux Home behind the overlay so the blur + scrim read like the real thing.
        ZStack {
            LinearGradient(colors: [FudoColor.bgCard, FudoColor.bgPrimary],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RankUpOverlayView(reachedRank: .warrior, store: store, onClose: {})
        }
        .preferredColorScheme(.dark)
    } else {
        Text("Preview container failed")
    }
}
#endif
