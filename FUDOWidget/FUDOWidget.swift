//
//  FUDOWidget.swift
//  FUDOWidget
//
//  Small + medium home-screen widgets. Read-only: they render a `WidgetSnapshot`
//  written by the app into the App Group (model P7) and touch nothing else —
//  no SwiftData, no RevenueCat, no PostHog. Identity mirrors the Home hero
//  (vermillon ensō ring + flame + giant OVR), dark, design-system tokens only.
//
//  Renders in all three widget modes: .fullColor (home screen), .accented
//  (tinted) and .vibrant (transparent). Custom colors survive only in fullColor;
//  the other two desaturate by luminance and turn SOLID FILLS into blobs, so the
//  flame pill's fill is fullColor-only and the hero glyphs opt into the accent
//  group via .widgetAccentable() — layout is VStack-stacked so nothing overlaps.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?   // nil == app never opened (empty state)
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        // Gallery preview: show a filled sample rather than an empty card.
        completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        // Current state now + one refresh just after midnight so "Day X" can't
        // linger from yesterday. The app recomputes exact state at next open;
        // the widget only needs to stop showing a stale day number.
        let entry = SnapshotEntry(date: now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(Self.nextRefreshDate(after: now))))
    }

    static func nextRefreshDate(after date: Date) -> Date {
        let cal = Calendar.current
        let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
        let midnight = cal.startOfDay(for: nextDay)
        // A few minutes past midnight so the day has truly rolled.
        return cal.date(byAdding: .minute, value: 5, to: midnight) ?? midnight
    }
}

// MARK: - Entry view (dispatch)

struct FUDOWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SnapshotEntry

    var body: some View {
        if let snap = entry.snapshot {
            switch family {
            case .systemMedium: MediumWidgetView(snap: snap)
            default:            SmallWidgetView(snap: snap)
            }
        } else {
            EmptyWidgetView()
        }
    }
}

// MARK: - Small

struct SmallWidgetView: View {
    let snap: WidgetSnapshot

    var body: some View {
        if snap.hasActiveChallenge {
            // Stacked, not overlaid: the ring gets the flexible middle band so it
            // can never clip the flame row or the day label (device bug fix).
            VStack(spacing: 4) {
                HStack { FlamePill(streak: snap.streak); Spacer() }
                HeroDial(snap: snap, lineWidth: 7, ovrSize: 36)
                    .frame(maxHeight: .infinity)
                DayLabel(dayIndex: snap.dayIndex, totalDays: snap.totalDays)
            }
        } else {
            // Between challenges — rank + OVR + retention CTA.
            VStack(spacing: 6) {
                HeroDial(snap: snap, lineWidth: 6, ovrSize: 34)
                    .frame(maxHeight: .infinity)
                Text("New challenge?")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetPalette.accent)
                    .widgetAccentable()
            }
        }
    }
}

// MARK: - Medium

struct MediumWidgetView: View {
    let snap: WidgetSnapshot

    var body: some View {
        HStack(spacing: 12) {
            heroColumn
                .frame(width: 116)
            Rectangle()
                .fill(WidgetPalette.border)
                .frame(width: 1)
            rightColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var heroColumn: some View {
        if snap.hasActiveChallenge {
            VStack(spacing: 4) {
                HStack { FlamePill(streak: snap.streak); Spacer() }
                HeroDial(snap: snap, lineWidth: 6, ovrSize: 32)
                    .frame(maxHeight: .infinity)
                DayLabel(dayIndex: snap.dayIndex, totalDays: snap.totalDays)
            }
        } else {
            HeroDial(snap: snap, lineWidth: 6, ovrSize: 32)
        }
    }

    @ViewBuilder
    private var rightColumn: some View {
        if !snap.hasActiveChallenge {
            VStack(alignment: .leading, spacing: 5) {
                Spacer(minLength: 0)
                Text("New challenge?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(WidgetPalette.accent)
                    .widgetAccentable()
                Text("Start your next monk mode.")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetPalette.textSecondary)
                Spacer(minLength: 0)
            }
        } else if snap.remainingCount == 0 {
            // All non-negotiables done — no empty list, a sealed-day state.
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(WidgetPalette.celebrationGold)
                    .widgetAccentable()
                Text("Day \(snap.dayIndex) sealed")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WidgetPalette.celebrationGold)
                Text("All non-negotiables done.")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetPalette.textSecondary)
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 7) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(WidgetPalette.textSecondary)
                ForEach(Array(snap.remainingTasks.enumerated()), id: \.offset) { _, task in
                    TaskRow(task: task)
                }
                if snap.remainingCount > snap.remainingTasks.count {
                    Text("+\(snap.remainingCount - snap.remainingTasks.count) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct TaskRow: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: task.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetPalette.accent)
                .frame(width: 18)
                .widgetAccentable()
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetPalette.textPrimary)
                .lineLimit(1)
        }
    }
}

// MARK: - Empty (app never opened)

struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(WidgetPalette.accent, lineWidth: 5)
                    .frame(width: 46, height: 46)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(WidgetPalette.flame)
            }
            .widgetAccentable()
            Text("Start your monk mode.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetPalette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared components

/// Ensō ring + centered giant OVR + rank. Ring is a progress arc during a
/// challenge (day X / Y), a full static ring between challenges (identity).
private struct HeroDial: View {
    let snap: WidgetSnapshot
    let lineWidth: CGFloat
    let ovrSize: CGFloat

    var body: some View {
        ZStack {
            ProgressRing(progress: fraction, lineWidth: lineWidth)
            VStack(spacing: 1) {
                Text("\(snap.ovr)")
                    .font(.system(size: ovrSize, weight: .bold).monospacedDigit())
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(snap.rankName.uppercased())
                    .font(.system(size: max(9, ovrSize * 0.26), weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(WidgetPalette.textSecondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, lineWidth + 4)
        }
    }

    /// nil during no-challenge → full static ring; else the day-progress arc.
    private var fraction: Double? {
        guard snap.hasActiveChallenge, snap.totalDays > 0 else { return nil }
        return Double(min(snap.dayIndex, snap.totalDays)) / Double(snap.totalDays)
    }
}

private struct ProgressRing: View {
    let progress: Double?   // nil == full accent ring (static ensō)
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            // Track stays in the default (desaturated) group so the accent arc
            // reads against it in tinted mode.
            Circle()
                .stroke(WidgetPalette.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.map { max(0.02, min(1, $0)) } ?? 1)
                .stroke(WidgetPalette.accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct FlamePill: View {
    // The pill's filled capsule is a solid shape → it renders as an opaque blob
    // in .accented / .vibrant. Drop the fill there and show the bare flame+count.
    @Environment(\.widgetRenderingMode) private var renderingMode
    let streak: Int

    private var isFullColor: Bool { renderingMode == .fullColor }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetPalette.flame)
                .widgetAccentable()
            Text("\(streak)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(WidgetPalette.textPrimary)
        }
        .padding(.horizontal, isFullColor ? 7 : 0)
        .padding(.vertical, isFullColor ? 4 : 0)
        .background {
            if isFullColor {
                Capsule()
                    .fill(WidgetPalette.bgCard)
                    .overlay(Capsule().stroke(WidgetPalette.border, lineWidth: 1))
            }
        }
    }
}

private struct DayLabel: View {
    let dayIndex: Int
    let totalDays: Int

    var body: some View {
        Text("DAY \(dayIndex) / \(totalDays)")
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .tracking(0.8)
            .foregroundStyle(WidgetPalette.textSecondary)
    }
}

// MARK: - Widget

struct FUDOWidget: Widget {
    let kind = "FUDOWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            FUDOWidgetEntryView(entry: entry)
                .containerBackground(WidgetPalette.bgPrimary, for: .widget)
                .widgetURL(URL(string: "fudo://home"))
        }
        .configurationDisplayName("FUDO")
        .description("Your streak, OVR and today's non-negotiables.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider sample (gallery / placeholder)

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        ovr: 84, rankName: "Warrior", streak: 12, dayIndex: 12, totalDays: 30,
        remainingTasks: [
            WidgetTask(title: "Cold shower", icon: "drop.fill"),
            WidgetTask(title: "Read 20 pages", icon: "book.fill"),
            WidgetTask(title: "Workout", icon: "figure.strengthtraining.traditional"),
        ],
        remainingCount: 3, hasActiveChallenge: true)

    static let sampleSealed = WidgetSnapshot(
        ovr: 84, rankName: "Warrior", streak: 12, dayIndex: 12, totalDays: 30,
        remainingTasks: [], remainingCount: 0, hasActiveChallenge: true)

    static let sampleNoChallenge = WidgetSnapshot(
        ovr: 71, rankName: "Warrior", streak: 0, dayIndex: 0, totalDays: 0,
        remainingTasks: [], remainingCount: 0, hasActiveChallenge: false)
}

#if DEBUG
#Preview("Small · active", as: .systemSmall) {
    FUDOWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: .sampleNoChallenge)
    SnapshotEntry(date: .now, snapshot: nil)
}

#Preview("Medium · active", as: .systemMedium) {
    FUDOWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: .sampleSealed)
    SnapshotEntry(date: .now, snapshot: .sampleNoChallenge)
    SnapshotEntry(date: .now, snapshot: nil)
}
#endif
