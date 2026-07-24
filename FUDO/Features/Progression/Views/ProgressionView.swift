import SwiftUI

/// The Progress tab — the trophy room. Top→bottom: sensei hero + giant OVR, the OVR curve,
/// the descending rank path, then past challenges (hidden when none). Calm and factual: the
/// pride comes from the numbers, so there are no celebration effects here. Composed to be
/// filmed (9:16) — no nav-bar title, nothing critical in the top corners.
struct ProgressionView: View {
    @State private var viewModel: ProgressionViewModel
    @State private var shareRequest: ShareCardRequest?
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
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

                shareButton

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
        .shareCardPreview($shareRequest)
    }

    /// Permanent share affordance — inline (not a top-corner toolbar: this screen
    /// is composed to be filmed, so nothing critical sits in the corners).
    @ViewBuilder private var shareButton: some View {
        // Hidden without a player so the affordance is never a silent no-op tap
        // (defensive — a player always exists past onboarding) — F17.
        if store.player != nil {
            Button {
                guard let data = ShareCardData.daily(from: store) else { return }
                Haptics.light()
                shareRequest = ShareCardRequest(variant: .daily, data: data, origin: .progress)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .fudoFont(.headline(15, weight: .semibold))
                    Text("Share your card")
                        .fudoFont(.headline(16))
                }
                .foregroundStyle(FudoColor.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(FudoColor.bgCard)
                        .overlay(Capsule().strokeBorder(FudoColor.border, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share your rank card")
        }
    }
}
