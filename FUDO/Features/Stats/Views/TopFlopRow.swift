import SwiftUI

/// Strongest / weakest habits, side by side (frame 05). The STRONGEST marker uses
/// `positive` (the validation/reco green exception, CLAUDE.md 2026-07-12); WEAKEST
/// uses vermillon — never `negative` red, which is reserved for the trend arrows.
/// Below 5 closed days (or fewer than 2 habits) it collapses to a calm "too early" card.
struct TopFlopRow: View {
    let topFlop: TopFlop?

    var body: some View {
        if let topFlop {
            HStack(spacing: 12) {
                card(marker: "STRONGEST", icon: "flame.fill", tint: FudoColor.positive,
                     habit: topFlop.strongest,
                     detail: streakLine(topFlop.strongest))
                card(marker: "WEAKEST", icon: "exclamationmark.triangle.fill", tint: FudoColor.accent,
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
                    .font(.system(size: 11, weight: .bold))
                Text(marker)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
            }
            .foregroundStyle(tint)

            Text(habit.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FudoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(FudoFont.caption(13))
                .foregroundStyle(FudoColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(marker): \(habit.title), \(detail)")
    }

    private var tooEarly: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FudoColor.textSecondary)
            Text("Strengths and weak spots need 5 days of data. Keep going.")
                .font(FudoFont.caption(13))
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
