import Foundation

/// A rule being composed at setup time — the mutable, UI-facing counterpart of
/// `RuleDraft`. Values (wake-up time) are baked into the title string on edit
/// (decision 2026-07-12): TaskRule keeps its title+icon schema, no migration.
struct EditableRule: Identifiable, Equatable {
    /// Drives the edit sheet: `.time` adds a time picker that rewrites the title.
    enum ValueKind: Equatable { case plain, time }

    let id: UUID
    var title: String
    var iconName: String
    var isEnabled: Bool
    var domain: String?          // v1.1 radar — settable in code, no UI in MVP
    var valueKind: ValueKind
    /// Minutes since midnight — meaningful for `.time` rules only.
    var timeMinutes: Int

    init(id: UUID = UUID(), title: String, iconName: String, isEnabled: Bool = true,
         domain: String? = nil, valueKind: ValueKind = .plain,
         timeMinutes: Int = PresetCatalog.defaultWakeMinutes) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isEnabled = isEnabled
        self.domain = domain
        self.valueKind = valueKind
        self.timeMinutes = timeMinutes
    }

    var draft: RuleDraft { RuleDraft(title: title, iconName: iconName, domain: domain) }

    /// "7:00" / "21:30" — plain 24 h clock, matching the frame-04 copy.
    static func formattedTime(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

/// One choosable challenge preset: identity, duration, pitch, default protocol.
struct PresetDefinition: Identifiable {
    let preset: ChallengePreset
    let durationDays: Int
    let title: String
    let tagline: String
    let defaultRules: [EditableRule]

    var id: ChallengePreset { preset }
}

/// The four launchable presets (MVP feature 1). Single source for every skin —
/// preset cards, duration chips and the onboarding inline variant all read here.
/// NOTE: the trademarked name "75 Hard" must never appear anywhere in the app.
enum PresetCatalog {
    static let defaultWakeMinutes = 7 * 60

    static func wakeUpRule(minutes: Int = defaultWakeMinutes) -> EditableRule {
        EditableRule(title: "Wake up before \(EditableRule.formattedTime(minutes: minutes))",
                     iconName: "sunrise.fill", valueKind: .time, timeMinutes: minutes)
    }

    private static var monkCore: [EditableRule] {
        [EditableRule(title: "Daily workout", iconName: "figure.strengthtraining.traditional"),
         EditableRule(title: "Cold shower", iconName: "drop.fill"),
         EditableRule(title: "Read 30 min", iconName: "book.fill"),
         EditableRule(title: "Social media under 1h", iconName: "iphone.slash"),
         wakeUpRule()]
    }

    /// Hardcore 90 and Monk Mode 120 share the full protocol — 120 is the same
    /// discipline held longer, not a different one.
    private static var hardcoreProtocol: [EditableRule] {
        monkCore
            + [EditableRule(title: "Meditate 10 min", iconName: "figure.mind.and.body"),
               EditableRule(title: "No alcohol", iconName: "wineglass"),
               EditableRule(title: "One-line journal", iconName: "square.and.pencil")]
    }

    // Taglines re-cut for the 11a duration cards (Romain, batch #2 2026-07-16) —
    // ONE source, so the full-flow cards and the standalone line say the same thing.
    static var all: [PresetDefinition] {
        [PresetDefinition(preset: .monk30, durationDays: 30, title: "Monk Mode 30",
                          tagline: "The reset", defaultRules: monkCore),
         PresetDefinition(preset: .monk60, durationDays: 60, title: "Monk Mode 60",
                          tagline: "The standard",
                          defaultRules: monkCore
                            + [EditableRule(title: "Meditate 10 min", iconName: "figure.mind.and.body")]),
         // "Monk Mode 90" since batch #3 (Romain): one family, four lengths —
         // the `hardcore90` case stays as the DATA identity of old challenges.
         PresetDefinition(preset: .hardcore90, durationDays: 90, title: "Monk Mode 90",
                          tagline: "For the strong", defaultRules: hardcoreProtocol),
         PresetDefinition(preset: .monk120, durationDays: 120, title: "Monk Mode 120",
                          tagline: "The ultimate", defaultRules: hardcoreProtocol)]
    }

    /// Retired presets keep their display name for PAST challenges — they are no
    /// longer launchable (chips 2026-07-16: the 75 gave its slot to the 120).
    private static let retiredTitles: [ChallengePreset: String] = [
        .classic75: "The Classic 75"
    ]

    static func definition(for preset: ChallengePreset) -> PresetDefinition {
        all.first { $0.preset == preset } ?? all[0]
    }

    /// The fullest standard protocol (Monk Mode 90/120) — the source pool for the
    /// "Restart harder" escalation: the discipline held at its hardest.
    static var fullProtocol: [EditableRule] { hardcoreProtocol }

    /// Up to `limit` standard-protocol rules the user isn't already running
    /// (matched by SF Symbol), in protocol order — the "Restart harder" additions.
    /// Returns fewer (or none) when he already runs the whole protocol.
    static func hardenAdditions(excludingIcons icons: Set<String>, limit: Int) -> [EditableRule] {
        guard limit > 0 else { return [] }
        return Array(fullProtocol.filter { !icons.contains($0.iconName) }.prefix(limit))
    }

    /// Display name of any preset — the ONE source (audit 2026-07-15: Progression
    /// used to re-declare its own list and drifted to "Classic 75"). `.custom` has
    /// no catalog entry, so it is named from its own duration.
    static func title(for preset: ChallengePreset, days: Int) -> String {
        all.first { $0.preset == preset }?.title ?? retiredTitles[preset] ?? "Custom \(days)"
    }

    /// Duration chips: 30 / 60 / 90 / 120 each map to a preset (2026-07-16).
    static func definition(forDays days: Int) -> PresetDefinition? {
        all.first { $0.durationDays == days }
    }

    static var chipDays: [Int] { all.map(\.durationDays).sorted() }
}

/// Curated icon choices for the rule edit sheet — small on purpose, every symbol
/// legible at row size on the dark palette.
enum RuleIconCatalog {
    static let symbols = [
        "figure.strengthtraining.traditional", "figure.run", "figure.mind.and.body",
        "drop.fill", "waterbottle.fill", "fork.knife",
        "book.fill", "square.and.pencil", "brain.head.profile",
        "iphone.slash", "wineglass", "camera.fill",
        "sunrise.fill", "moon.fill", "bed.double.fill", "flame.fill"
    ]

    static let defaultSymbol = "flame.fill"
}
