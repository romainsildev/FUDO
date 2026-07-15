import Foundation

/// Codable value types embedded in the @Model entities (added in the data session),
/// plus the enums shared across the app. No SwiftData here. Verbatim from DATA-MODEL §2.

struct TaskCheck: Codable, Equatable {
    let ruleID: UUID        // references TaskRule.id
    let checkedAt: Date     // exact hold-to-check time
    let ovrDelta: Double    // exact delta granted → exact reversal on uncheck
}

struct OVRPoint: Codable, Equatable {
    let date: Date          // startOfDay
    let value: Double       // ovrValue after the day's delta
}

enum ChallengePreset: String, Codable { case monk30, monk60, hardcore90, classic75, custom }
enum ChallengeStatus: String, Codable { case active, completed, abandoned }

/// Derived from OVR, never persisted.
/// Novice 0-49 · Disciple 50-59 · Ascetic 60-69 · Warrior 70-79 · Master 80-89 · Sensei 90-99
enum Rank: Int, CaseIterable {
    case novice, disciple, ascetic, warrior, master, sensei

    /// Decay floor = bottom of the rank band. Thresholds live here (single source), not in GameConfig.
    var floorOVR: Double { [0, 50, 60, 70, 80, 90][rawValue] }

    /// EN display name — the ONE source (Progression, the onboarding, and every
    /// screen after them read this). UI strings are English per CLAUDE.md.
    var displayName: String {
        switch self {
        case .novice: return "Novice"
        case .disciple: return "Disciple"
        case .ascetic: return "Ascetic"
        case .warrior: return "Warrior"
        case .master: return "Master"
        case .sensei: return "Sensei"
        }
    }

    static func from(ovr: Double) -> Rank {
        switch ovr {
        case ..<50: return .novice
        case ..<60: return .disciple
        case ..<70: return .ascetic
        case ..<80: return .warrior
        case ..<90: return .master
        default:    return .sensei
        }
    }
}
