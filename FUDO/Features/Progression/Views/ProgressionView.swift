import SwiftUI

/// The Progress tab — the trophy room. Top→bottom: sensei hero + giant OVR, the OVR curve,
/// the descending rank path, then past challenges (hidden when none). Calm and factual: the
/// pride comes from the numbers, so there are no celebration effects here. Composed to be
/// filmed (9:16) — no nav-bar title, nothing critical in the top corners.
struct ProgressionView: View {
    @State private var viewModel: ProgressionViewModel

    init(store: GameStore) {
        _viewModel = State(initialValue: ProgressionViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FudoSpacing.sectionGap) {
                Text("Progression")
                    .fudoFont(.title(34))
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 4)

                SenseiHeroView(rank: viewModel.heroRank,
                               ovr: viewModel.displayedOVR,
                               rankName: viewModel.heroRankName,
                               ordinal: viewModel.rankOrdinalLabel)

                OVRCurveView(points: viewModel.curvePoints,
                             windowLabel: viewModel.curveWindowLabel,
                             weekNet: viewModel.weekNet)

                RankPathView(nodes: viewModel.rankNodes)

                PastChallengesView()
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, FudoSpacing.sectionGap)
        }
        .scrollIndicators(.hidden)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
    }
}
