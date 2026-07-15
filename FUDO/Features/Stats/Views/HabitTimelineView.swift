import SwiftUI

/// Step-by-step history (frame 05b), most recent on top. A connected gutter of dots:
/// held (green · time), missed (red · "missed"), today still open (vermillon · "in
/// progress"). Green/red status follows the same precedent as the Progression popover.
struct HabitTimelineView: View {
    let entries: [TimelineEntry]

    private var firstID: Int? { entries.first?.id }
    private var lastID: Int? { entries.last?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                row(entry, isFirst: entry.id == firstID, isLast: entry.id == lastID)
            }
        }
    }

    private func row(_ entry: TimelineEntry, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            gutter(entry, isFirst: isFirst, isLast: isLast)
            HStack {
                Text("Day \(entry.dayNumber)")
                    .fudoFont(.headline(16))
                    .foregroundStyle(FudoColor.textPrimary)
                Spacer(minLength: 8)
                trailing(entry)
            }
            .padding(.vertical, 14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label(for: entry))
    }

    /// Dot + connector line. Fixed height so the line meets the neighbours cleanly.
    private func gutter(_ entry: TimelineEntry, isFirst: Bool, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : FudoColor.border)
                .frame(width: 2)
            Circle()
                .fill(dotColor(entry))
                .frame(width: 11, height: 11)
            Rectangle()
                .fill(isLast ? Color.clear : FudoColor.border)
                .frame(width: 2)
        }
        .frame(width: 12)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func trailing(_ entry: TimelineEntry) -> some View {
        switch entry.state {
        case .held:
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .fudoFont(.body(12, weight: .bold))
                    .foregroundStyle(FudoColor.positive)
                Text(entry.timeLabel ?? "checked")
                    .fudoFont(.stat(15, weight: .regular))
                    .foregroundStyle(FudoColor.textSecondary)
            }
        case .missed:
            HStack(spacing: 5) {
                Image(systemName: "xmark")
                    .fudoFont(.body(12, weight: .bold))
                Text("missed")
                    .fudoFont(.body(15))
            }
            .foregroundStyle(FudoColor.negative)
        case .todayOpen:
            Text("in progress")
                .fudoFont(.body(15))
                .foregroundStyle(FudoColor.textSecondary)
        }
    }

    private func dotColor(_ entry: TimelineEntry) -> Color {
        switch entry.state {
        case .held:      FudoColor.positive
        case .missed:    FudoColor.negative
        case .todayOpen: FudoColor.accent
        }
    }

    private func label(for entry: TimelineEntry) -> String {
        switch entry.state {
        case .held:      "Day \(entry.dayNumber), checked \(entry.timeLabel ?? "")"
        case .missed:    "Day \(entry.dayNumber), missed"
        case .todayOpen: "Day \(entry.dayNumber), in progress"
        }
    }
}
