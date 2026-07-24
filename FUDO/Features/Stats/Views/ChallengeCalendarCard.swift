import SwiftUI

/// The challenge map (Habit FINAL, 2026-07-23): the whole run as a 6-column grid —
/// replaces the massive 7-day blocks and the silly two-slab week view. Cream cell ✓ =
/// held, red-rimmed ✕ = missed, vermillon ring = today, dim = still ahead. One glance:
/// the entire fight, where it broke, how much is left.
struct ChallengeCalendarCard: View {
    let days: [CalendarDay]
    let dayNumber: Int
    let durationDays: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHALLENGE MAP — DAY \(dayNumber) OF \(durationDays)")
                .fudoFont(.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days) { day in
                    cell(for: day)
                }
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    private func cell(for day: CalendarDay) -> some View {
        VStack(spacing: 2) {
            Text("\(day.dayNumber)")
                .fudoFont(.stat(12))
                .foregroundStyle(numberColor(for: day))
            glyph(for: day)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fillColor(for: day))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(rimColor(for: day), lineWidth: day.isToday ? 2 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day.dayNumber): \(accessibilityState(for: day))")
    }

    @ViewBuilder private func glyph(for day: CalendarDay) -> some View {
        switch day.state {
        case .held:
            Image(systemName: "checkmark")
                .fudoFont(.glyph(8, weight: .bold))
                .foregroundStyle(FudoColor.bgPrimary.opacity(0.65))
        case .missed:
            Image(systemName: "xmark")
                .fudoFont(.glyph(8, weight: .bold))
                .foregroundStyle(FudoColor.negative)
        case .open, .future:
            Color.clear.frame(height: 8)
        }
    }

    private func fillColor(for day: CalendarDay) -> Color {
        switch day.state {
        case .held:   return FudoColor.textPrimary.opacity(0.92)
        case .missed: return FudoColor.negative.opacity(0.10)
        case .open:   return FudoColor.surfaceGlass
        case .future: return Color.white.opacity(0.04)
        }
    }

    private func rimColor(for day: CalendarDay) -> Color {
        if day.isToday { return FudoColor.accent }
        switch day.state {
        case .missed: return FudoColor.negative.opacity(0.5)
        default:      return .clear
        }
    }

    private func numberColor(for day: CalendarDay) -> Color {
        switch day.state {
        case .held:   return FudoColor.bgPrimary
        case .missed: return FudoColor.negative
        case .open:   return FudoColor.textPrimary
        case .future: return FudoColor.textSecondary.opacity(0.55)
        }
    }

    private func accessibilityState(for day: CalendarDay) -> String {
        switch day.state {
        case .held:   return "done"
        case .missed: return "missed"
        case .open:   return "today, open"
        case .future: return "ahead"
        }
    }
}
