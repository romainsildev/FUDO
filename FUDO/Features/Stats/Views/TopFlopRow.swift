import SwiftUI

/// Strongest / weakest habits, side by side (frame 05). Semantics repaired 2026-07-23:
/// STRONGEST is gold (an achievement — warm, not the reco-green), WEAKEST is `negative`
/// red — the one legitimate red on this screen. Each card wears its tint as a quiet
/// border. Below 5 closed days (or fewer than 2 habits) it collapses to "too early".
struct TopFlopRow: View {
    let topFlop: TopFlop?

    var body: some View {
        if let topFlop {
            HStack(spacing: 12) {
                card(marker: "STRONGEST", icon: "flame.fill", tint: FudoColor.celebrationGold,
                     habit: topFlop.strongest,
                     detail: streakLine(topFlop.strongest))
                card(marker: "WEAKEST", icon: "exclamationmark.triangle.fill", tint: FudoColor.negative,
                     habit: topFlop.weakest,
                     detail: missedLine(topFlop.weakest))
            }
        } else {
            tooEarly
        }
    }

    private func streakLine(_ h: HabitStat) -> String {
        "\(h.completionPercent)% · \(h.streak)-day streak"
    }

    private func missedLine(_ h: HabitStat) -> String {
        "\(h.completionPercent)% · \(h.missedCount) missed"
    }

    private func card(marker: String, icon: String, tint: Color,
                      habit: HabitStat, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .fudoFont(.label(11, weight: .bold))
                Text(marker)
                    .fudoFont(.label(11, weight: .bold))
                    .kerning(1)
            }
            .foregroundStyle(tint)

            Text(habit.title)
                .fudoFont(.headline(16))
                .foregroundStyle(FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .fudoFont(.caption(13))
                .foregroundStyle(FudoColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(marker): \(habit.title), \(detail)")
    }

    private var tooEarly: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .fudoFont(.caption(14, weight: .semibold))
                .foregroundStyle(FudoColor.textSecondary)
            Text("Strengths and weak spots need 5 days of data. Keep going.")
                .fudoFont(.caption(13))
                .foregroundStyle(FudoColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(FudoSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }
}
