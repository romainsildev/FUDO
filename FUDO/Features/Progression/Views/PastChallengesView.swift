import SwiftUI
import SwiftData

/// Compact history of finished challenges (completed or abandoned). The whole section is
/// hidden when there are none — never an empty state. Reads via `@Query` (iOS 17 `#Predicate`
/// can't match the Codable status enum, so filter in memory, matching GameStore's approach).
struct PastChallengesView: View {
    @Query(sort: \Challenge.startDate, order: .reverse) private var challenges: [Challenge]

    private var finished: [Challenge] {
        challenges.filter { $0.status == .completed || $0.status == .abandoned }
    }

    var body: some View {
        if !finished.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("PAST CHALLENGES")
                    .font(FudoFont.caption(13))
                    .tracking(1.5)
                    .foregroundStyle(FudoColor.textSecondary)

                ForEach(finished) { PastChallengeCard(challenge: $0) }
            }
        }
    }
}

/// One finished challenge: preset · dates · result · final OVR.
private struct PastChallengeCard: View {
    let challenge: Challenge

    private var completed: Bool { challenge.status == .completed }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(PresetCatalog.title(for: challenge.preset, days: challenge.durationDays))
                    .font(FudoFont.title(17))
                    .foregroundStyle(FudoColor.textPrimary)
                Text(dateRange)
                    .font(FudoFont.caption(13))
                    .foregroundStyle(FudoColor.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(completed ? "Completed" : "Abandoned")
                    .font(FudoFont.caption(12).weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(completed ? FudoColor.accent : FudoColor.textSecondary)
                if let endOVR = challenge.endOVR {
                    Text("OVR \(OVREngine.displayedOVR(endOVR))")
                        .font(FudoFont.body(15).weight(.semibold).monospacedDigit())
                        .foregroundStyle(FudoColor.textPrimary)
                }
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        )
    }

    private var dateRange: String {
        "\(ProgressionViewModel.shortDate(challenge.startDate)) – \(ProgressionViewModel.shortDate(challenge.endDate))"
    }
}
