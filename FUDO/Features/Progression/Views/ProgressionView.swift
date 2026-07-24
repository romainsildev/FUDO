import SwiftUI

/// The Progress tab — the trophy room (02 Progression re-skin, 2026-07-24). Top→bottom:
/// the OVR ring hero, the OVR history bars, the descending rank path, then past challenges
/// (hidden when none). Calm and factual: the pride comes from the numbers, so there are no
/// celebration effects here. On a warm ink gradient with a faint top halo.
struct ProgressionView: View {
    @State private var viewModel: ProgressionViewModel
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
        _viewModel = State(initialValue: ProgressionViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FudoSpacing.sectionGap) {
                Text("Progression")
                    .fudoFont(.title(34))          // iOS large-title size (HIG) — matches Stats/Home
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 4)

                OVRRingHeroView(rank: viewModel.heroRank,
                                ovr: viewModel.displayedOVR,
                                rankName: viewModel.heroRankName,
                                ordinal: viewModel.rankOrdinalLabel,
                                progress: viewModel.rankProgress)

                OVRBarsView(points: viewModel.curvePoints,
                            windowLabel: viewModel.curveWindowLabel,
                            weekNet: viewModel.weekNet)

                RankPathView(nodes: viewModel.rankNodes)

                PastChallengesView()
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, FudoSpacing.sectionGap)
        }
        .scrollIndicators(.hidden)
        .background(background)
    }

    /// Warm ink gradient (silhouette → ink) with a faint vermillon halo up top — the
    /// ambient "trophy room" light, matching the 02 Progression frame.
    private var background: some View {
        LinearGradient(colors: [FudoColor.silhouette, FudoColor.bgPrimary],
                       startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .top) {
                Circle()
                    .fill(FudoColor.accent.opacity(0.07))
                    .frame(width: 420, height: 420)
                    .blur(radius: 80)
                    .offset(x: -40, y: -180)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}
