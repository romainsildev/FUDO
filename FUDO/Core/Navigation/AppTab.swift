import Foundation

/// The 4 tab destinations. Tab switch only — never a cross-tab push.
enum AppTab: Int, CaseIterable, Hashable {
    case today, progress, stats, settings

    var title: String {
        switch self {
        case .today: return "Today"
        case .progress: return "Progress"
        case .stats: return "Stats"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "house.fill"                 // DesignReference/app: house
        case .progress: return "chart.bar.fill"          // bars
        case .stats: return "chart.line.uptrend.xyaxis"  // trend line
        case .settings: return "gearshape.fill"          // gear
        }
    }
}
