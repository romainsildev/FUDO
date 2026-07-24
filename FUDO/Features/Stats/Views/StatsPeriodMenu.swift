import SwiftUI

/// The period selector as a compact header pill (2026-07-23 — replaces the segmented
/// control, device verdict: three fat buttons ate a whole row). "Last 7 days ⌄" opens
/// a native Menu; the system draws the checkmark on the selected period.
struct StatsPeriodMenu: View {
    @Binding var period: StatsPeriod

    var body: some View {
        Menu {
            Picker("Period", selection: $period) {
                ForEach(StatsPeriod.allCases, id: \.self) { period in
                    Text(period.menuLabel).tag(period)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(period.menuLabel)
                    .fudoFont(.headline(13, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
                Image(systemName: "chevron.down")
                    .fudoFont(.caption(10, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(FudoColor.surfaceGlass)
                    .overlay(Capsule().strokeBorder(FudoColor.borderGlass, lineWidth: 1))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stats period: \(period.menuLabel)")
    }
}
