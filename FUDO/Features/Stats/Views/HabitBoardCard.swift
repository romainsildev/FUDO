import SwiftUI

/// The game board (Habit FINAL v3-B3, 2026-07-24): the whole run laid out as a
/// snakes-and-ladders trail — six columns per row, rows alternating left→right /
/// right→left, a vermillon connector running the walked path and a dashed one for the
/// days ahead. Replaces the flat 6-column grid (`ChallengeCalendarCard` is orphaned).
/// Pure render over the existing `CalendarDay` data — nothing new is captured.
///
/// Colour semantics (CLAUDE.md 2026-07-23): held = cream disc, missed = the only red
/// (a failure signal), today = vermillon ring + glow (the accent), future = a dim well,
/// last day = a gold rim (the trophy at the end of the trail).
struct HabitBoardCard: View {
    let days: [CalendarDay]
    let dayNumber: Int
    let durationDays: Int

    private let columns = 6
    private let cellSize: CGFloat = 30
    private let rowHeight: CGFloat = 50

    private var rowCount: Int {
        max(Int((Double(days.count) / Double(columns)).rounded(.up)), 1)
    }

    /// Index of the furthest walked cell — today, or the last non-future day for a
    /// finished run. Everything up to here gets the solid vermillon connector.
    private var progressIndex: Int {
        days.firstIndex(where: \.isToday)
            ?? days.lastIndex(where: { $0.state != .future })
            ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THE BOARD — DAY \(dayNumber) OF \(durationDays)")
                .fudoFont(.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)

            GeometryReader { geo in
                let colWidth = geo.size.width / CGFloat(columns)
                ZStack {
                    connector(colWidth: colWidth, solid: true)
                    connector(colWidth: colWidth, solid: false)
                    ForEach(days) { day in
                        cell(for: day)
                            .position(center(day.dayNumber - 1, colWidth: colWidth))
                    }
                }
            }
            .frame(height: CGFloat(rowCount) * rowHeight)

            HStack {
                Spacer()
                Text("DAY \(durationDays) — SENSEI SEAL")
                    .fudoFont(.label(9, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(FudoColor.celebrationGold)
            }
        }
        .padding(FudoSpacing.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                .fill(FudoColor.bgCard)
                .strokeBorder(FudoColor.border, lineWidth: 1)
        }
    }

    // MARK: - Geometry

    /// Centre of cell `index` (0-based). Even rows run left→right, odd rows fold back
    /// right→left, so the last cell of a row sits above the first of the next — the
    /// vertical drop of a goose-game board.
    private func center(_ index: Int, colWidth: CGFloat) -> CGPoint {
        let row = index / columns
        let posInRow = index % columns
        let col = row.isMultiple(of: 2) ? posInRow : (columns - 1 - posInRow)
        return CGPoint(x: colWidth * (CGFloat(col) + 0.5),
                       y: rowHeight * (CGFloat(row) + 0.5))
    }

    // MARK: - Connector

    @ViewBuilder private func connector(colWidth: CGFloat, solid: Bool) -> some View {
        Path { path in
            guard days.count >= 2 else { return }
            for i in 0..<(days.count - 1) {
                let walked = (i + 1) <= progressIndex
                guard walked == solid else { continue }
                path.move(to: center(i, colWidth: colWidth))
                path.addLine(to: center(i + 1, colWidth: colWidth))
            }
        }
        .stroke(solid ? FudoColor.accent : FudoColor.textPrimary.opacity(0.14),
                style: solid
                    ? StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    : StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [3, 5]))
    }

    // MARK: - Cell

    private func cell(for day: CalendarDay) -> some View {
        ZStack {
            if day.isToday {
                Circle()
                    .fill(FudoColor.accent.opacity(0.25))
                    .frame(width: cellSize + 12, height: cellSize + 12)
                    .blur(radius: 6)
            }
            Circle()
                .fill(fillColor(for: day))
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    Circle().strokeBorder(strokeColor(for: day), lineWidth: strokeWidth(for: day))
                }
            Text("\(day.dayNumber)")
                .fudoFont(.stat(11))
                .foregroundStyle(numberColor(for: day))
        }
        .frame(width: cellSize, height: cellSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day.dayNumber): \(a11yState(for: day))")
    }

    private var isLastDay: (CalendarDay) -> Bool { { $0.dayNumber == durationDays } }

    private func fillColor(for day: CalendarDay) -> Color {
        switch day.state {
        case .held:   FudoColor.textPrimary.opacity(0.92)
        case .missed: FudoColor.negative.opacity(0.10)
        case .open:   FudoColor.bgPrimary
        case .future: FudoColor.bgPrimary
        }
    }

    private func strokeColor(for day: CalendarDay) -> Color {
        if day.isToday { return FudoColor.accent }
        if isLastDay(day) { return FudoColor.celebrationGold }
        switch day.state {
        case .missed: return FudoColor.negative
        case .future: return Color.white.opacity(0.08)
        case .held, .open: return .clear
        }
    }

    private func strokeWidth(for day: CalendarDay) -> CGFloat {
        if day.isToday { return 2.5 }
        if isLastDay(day) { return 1.5 }
        switch day.state {
        case .missed: return 1.5
        case .future: return 1
        case .held, .open: return 0
        }
    }

    private func numberColor(for day: CalendarDay) -> Color {
        switch day.state {
        case .held:   FudoColor.bgPrimary
        case .missed: FudoColor.negative
        case .open:   FudoColor.textPrimary
        case .future: FudoColor.textSecondary.opacity(0.55)
        }
    }

    private func a11yState(for day: CalendarDay) -> String {
        switch day.state {
        case .held:   "done"
        case .missed: "missed"
        case .open:   "today, open"
        case .future: isLastDay(day) ? "the seal, ahead" : "ahead"
        }
    }
}

#if DEBUG
#Preview("Game board") {
    // The Figma frame: days 1–7 held, day 8 missed, 9–12 held, 12 = today, 13–30 ahead.
    let days: [CalendarDay] = (1...30).map { d in
        let state: CalendarDay.State
        if d == 8 { state = .missed }
        else if d <= 12 { state = .held }
        else { state = .future }
        return CalendarDay(id: d, dayNumber: d, state: state, isToday: d == 12)
    }
    return ScrollView {
        HabitBoardCard(days: days, dayNumber: 12, durationDays: 30)
            .padding(FudoSpacing.screenMargin)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FudoColor.bgPrimary)
    .preferredColorScheme(.dark)
}

#Preview("Game board — 90 days") {
    let days: [CalendarDay] = (1...90).map { d in
        let state: CalendarDay.State
        if d % 9 == 0 { state = .missed }
        else if d <= 40 { state = .held }
        else { state = .future }
        return CalendarDay(id: d, dayNumber: d, state: state, isToday: d == 40)
    }
    return ScrollView {
        HabitBoardCard(days: days, dayNumber: 40, durationDays: 90)
            .padding(FudoSpacing.screenMargin)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FudoColor.bgPrimary)
    .preferredColorScheme(.dark)
}
#endif
