import SwiftUI

/// Flame sheet (D3, frame 09) — .medium detent, grabber, swipe-down, ZERO outgoing
/// navigation. Presented via `.fudoSheet` which owns detent/grabber/background.
/// Everything on screen is aggregated from DayLog (DATA-MODEL §Agrégations).
struct FlameSheetView: View {
    let viewModel: HomeViewModel

    private var isDead: Bool { viewModel.streak == 0 }

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 36)
            weekRow
                .padding(.top, 36)
            statsRow
                .padding(.top, 36)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FudoSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FudoColor.bgPrimary)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(isDead ? FudoColor.textSecondary.opacity(0.5) : FudoColor.accent)
            Text("\(viewModel.streak)")
                .font(FudoFont.ovr(76))
                .foregroundStyle(FudoColor.textPrimary)
            if isDead {
                Text("Streak dead. Rebuild.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FudoColor.textPrimary)
            } else {
                Text("day streak")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.textSecondary)
            }
        }
    }

    // MARK: - Week (M T W T F S S)

    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.flameWeek) { day in
                VStack(spacing: 8) {
                    pastille(for: day.state)
                        .frame(width: 36, height: 36)
                    Text(day.letter)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(day.isToday ? FudoColor.accent : FudoColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func pastille(for state: FlameWeekDay.State) -> some View {
        switch state {
        case .done:
            ZStack {
                Circle().fill(FudoColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FudoColor.textPrimary)
            }
        case .missed:
            ZStack {
                Circle().fill(FudoColor.border.opacity(0.5))
                Image(systemName: "line.diagonal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
            }
        case .today(let progress):
            ZStack {
                Circle().strokeBorder(FudoColor.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(FudoColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5)   // align the arc onto the strokeBorder track
            }
        case .upcoming:
            Circle().strokeBorder(FudoColor.border, lineWidth: 1.5)
        case .idle:
            Circle().strokeBorder(FudoColor.border.opacity(0.5), lineWidth: 1.5)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: viewModel.totalChecksAllTime, label: "TOTAL CHECKS")
            Rectangle()
                .fill(FudoColor.border)
                .frame(width: 1, height: 36)
            stat(value: viewModel.bestStreak, label: "BEST STREAK")
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(FudoColor.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(FudoColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
