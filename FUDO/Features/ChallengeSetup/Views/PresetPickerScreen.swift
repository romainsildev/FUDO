import SwiftUI

/// Full-flow screen 1: vertical preset cards, recommended badge from the VM.
struct PresetPickerScreen: View {
    let viewModel: ChallengeSetupViewModel
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your challenge")
                    .font(FudoFont.title())
                    .foregroundStyle(FudoColor.textPrimary)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ForEach(PresetCatalog.all) { definition in
                    PresetCard(definition: definition,
                               isRecommended: definition.preset == viewModel.recommendedPreset,
                               isSelected: definition.preset == viewModel.selectedPreset) {
                        viewModel.select(definition.preset)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
        }
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.medium()
                onNext()
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: FudoSpacing.ctaHeight)
                    .background { Capsule().fill(FudoColor.accent) }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.bottom, 12)
            .background { FudoColor.bgPrimary.opacity(0.94).ignoresSafeArea(edges: .bottom) }
        }
        .navigationTitle("")
        .toolbarBackground(FudoColor.bgPrimary, for: .navigationBar)
    }
}
