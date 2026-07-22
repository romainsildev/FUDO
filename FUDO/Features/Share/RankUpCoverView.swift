import SwiftUI

/// The rank just crossed, presented once (D6 high-water mark). Identifiable so
/// RootView presents it with `.fullScreenCover(item:)` off `pendingRankUp`.
struct RankUpPresentation: Identifiable {
    let rank: Rank
    var id: Int { rank.rawValue }
}

/// Rank-up celebration cover — the new rank in scene, gold + vermillon burst,
/// then a Share CTA into the story card. The one loud moment: milestone only.
struct RankUpCoverView: View {
    let newRank: Rank
    let store: GameStore
    let onClose: () -> Void

    @State private var burstTrigger = 0
    @State private var appeared = false
    @State private var shareRequest: ShareCardRequest?

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            glow
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                eyebrow
                senseiWithBurst
                    .padding(.top, 8)
                Text(newRank.displayName.uppercased())
                    .fudoFont(.title(50, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(FudoColor.accent)
                    .padding(.top, 12)
                Text("OVR \(store.player?.displayedOVR ?? Int(newRank.floorOVR))")
                    .fudoFont(.metric(22))
                    .kerning(2)
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 8)
                Text("You've reached \(newRank.displayName). Keep the fire.")
                    .fudoFont(.body(15))
                    .foregroundStyle(FudoColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 40)
                Spacer(minLength: 24)
                ctaStack
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, FudoSpacing.contentBottom)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .shareCardPreview($shareRequest)
        .onAppear(perform: play)
    }

    private var eyebrow: some View {
        Text("RANK UP")
            .fudoFont(.label(15, weight: .heavy))
            .kerning(6)
            .foregroundStyle(FudoColor.celebrationGold)
    }

    private var senseiWithBurst: some View {
        SenseiAssetProvider.image(for: newRank)
            .resizable()
            .scaledToFit()
            .frame(height: 300)
            .overlay {
                ZStack {
                    GoldBurstView()
                    ParticleBurstView(color: FudoColor.accent,
                                      particleCount: ParticleBurstMetrics.celebrationCount,
                                      distance: 90...140,
                                      particleSize: 3...5,
                                      startDistance: 16,
                                      animation: AppAnimation.slow)
                }
                .id(burstTrigger)
            }
            .accessibilityLabel("\(newRank.displayName) sensei")
    }

    private var ctaStack: some View {
        VStack(spacing: 14) {
            Button {
                Haptics.medium()
                shareRequest = ShareCardRequest(
                    variant: .rankUp,
                    data: ShareCardData.rankUp(to: newRank, from: store))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .fudoFont(.headline(16, weight: .semibold))
                    Text("Share")
                        .fudoFont(.headline(17))
                }
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background(Capsule().fill(FudoColor.accent))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                onClose()
            } label: {
                Text("Continue")
                    .fudoFont(.headline(16))
                    .foregroundStyle(FudoColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    /// Faint gold + vermillon halo — celebration light behind the new rank.
    private var glow: some View {
        ZStack {
            RadialGradient(colors: [FudoColor.accentDeep.opacity(0.40), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 320)
            RadialGradient(colors: [FudoColor.celebrationGold.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.40), startRadius: 10, endRadius: 240)
        }
        .blur(radius: 30)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func play() {
        guard !appeared else { return }
        withAnimation(AppAnimation.slow) { appeared = true }
        burstTrigger += 1
        Haptics.success()
    }
}

#if DEBUG
import SwiftData

/// ONE in-memory container on the shared FudoSchema (SwiftData multi-container
/// pitfall 2026-07-12), seeded with the debug dataset — retained in a `static let`
/// so its context is never reset (canvas crash 2026-07-15).
@MainActor
private enum RankUpPreviewFactory {
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

#Preview("Rank-up — Warrior") {
    if let store = RankUpPreviewFactory.store {
        RankUpCoverView(newRank: .warrior, store: store, onClose: {})
            .preferredColorScheme(.dark)
    } else {
        Text("Preview container failed")
    }
}
#endif
