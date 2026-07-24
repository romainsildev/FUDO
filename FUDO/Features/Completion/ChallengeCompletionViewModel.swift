import Foundation
import Observation
import SwiftUI

/// The one view model behind the challenge-complete cover. Owns the beat paging,
/// the share export state (paywall-grade: loading / failure / retry), and the
/// next-hook derivations (superior preset, restart escalation). Pure reads off the
/// flattened `ChallengeCompletionSummary` — no GameStore, no `@Model`.
@MainActor
@Observable
final class ChallengeCompletionViewModel {
    /// The three sequential full-screen beats (Romain: pages, not one scroll).
    enum Beat: Int, CaseIterable { case verdict, share, hook }
    enum ExportState: Equatable { case idle, rendering, failed }

    let summary: ChallengeCompletionSummary
    var beat: Beat = .verdict
    var exportState: ExportState = .idle
    var sharePayload: CompletionSharePayload?

    init(summary: ChallengeCompletionSummary) { self.summary = summary }

    // MARK: - Beat 1 — verdict

    /// "30 days · 27 complete" — the factual headline number.
    var verdictLine: String {
        "\(summary.durationDays) days · \(summary.daysComplete) complete"
    }
    /// "3 missed" — only when he actually dropped days (a flawless run stays clean).
    var missedLine: String? {
        summary.daysMissed > 0 ? "\(summary.daysMissed) missed" : nil
    }
    /// "+33" / "-4" — the run's OVR move, honest either way.
    var gainBadge: String { String(format: "%+d", summary.ovrGain) }

    // MARK: - Beat 2 — share

    var shareData: ShareCardData { ShareCardData.challengeEnd(summary: summary) }

    /// Render off the main actor's next tick so the button flips to its spinner
    /// before the synchronous `ImageRenderer` blocks — same honest path as the
    /// standalone share preview.
    func export() {
        guard exportState != .rendering else { return }
        Haptics.medium()
        exportState = .rendering
        Task { @MainActor in
            if let image = ShareCardRenderer.render(data: shareData, variant: .challengeEnd) {
                exportState = .idle
                sharePayload = CompletionSharePayload(image: image)
            } else {
                exportState = .failed
            }
        }
    }

    var shareButtonLabel: String {
        switch exportState {
        case .idle:      return "Share"
        case .rendering: return "Preparing…"
        case .failed:    return "Try again"
        }
    }

    // MARK: - Beat 3 — the next hook

    /// The superior preset: the next longer chip, capped at the longest (120).
    /// A retired 75-day run maps up to 90.
    var superiorPreset: ChallengePreset {
        let days = summary.durationDays
        let harderDays = PresetCatalog.chipDays.first { $0 > days }
            ?? PresetCatalog.chipDays.last ?? days
        return PresetCatalog.definition(forDays: harderDays)?.preset ?? summary.preset
    }

    var superiorPresetTitle: String {
        PresetCatalog.definition(for: superiorPreset).title
    }

    /// "A Warrior doesn't stop at 76." — the rank IS the identity, so it leads.
    var hookLine: String {
        "A \(summary.endRank.displayName) doesn't stop at \(summary.endOVR)."
    }

    /// "You slipped most on Cold Shower." — cites (never hardens) the weakest rule.
    var restartSubtitle: String? {
        guard let title = summary.mostFailedRuleTitle else { return nil }
        return "You slipped most on \(title)."
    }

    /// Next challenge → the superior preset with its own default protocol.
    var nextIntent: ChallengeSetupIntent {
        ChallengeSetupIntent(recommendedPreset: superiorPreset,
                             initialPreset: superiorPreset, initialRules: nil)
    }

    /// Restart harder → SAME preset, the reused rules, plus up to 2 standard-protocol
    /// rules he wasn't running. Reused rules become `.plain` so their baked titles
    /// (e.g. a wake-up time) survive verbatim. The additions cap keeps the enabled
    /// set within `GameConfig.maxRules`, so the setup CTA never lands dead.
    var restartIntent: ChallengeSetupIntent {
        let reused = summary.reusedRules.map {
            EditableRule(title: $0.title, iconName: $0.iconName,
                         domain: $0.domain, valueKind: .plain)
        }
        let icons = Set(reused.map(\.iconName))
        let limit = max(0, min(2, GameConfig.maxRules - reused.count))
        let additions = PresetCatalog.hardenAdditions(excludingIcons: icons, limit: limit)
        return ChallengeSetupIntent(recommendedPreset: summary.preset,
                                    initialPreset: summary.preset,
                                    initialRules: reused + additions)
    }

    // MARK: - Navigation

    func advance() {
        guard let next = Beat(rawValue: beat.rawValue + 1) else { return }
        withAnimation(AppAnimation.standard) { beat = next }
    }

    /// Guards the terminal hook choice: a rapid double-tap before the cover
    /// dismisses must not fire `next_challenge_chosen` (or launch setup) twice.
    private var didChooseNext = false

    func chooseNext(_ launch: (ChallengeSetupIntent) -> Void) {
        guard !didChooseNext else { return }
        didChooseNext = true
        Analytics.track(AnalyticsEvent.nextChallengeChosen, ["option": "next"])
        launch(nextIntent)
    }

    func chooseRestart(_ launch: (ChallengeSetupIntent) -> Void) {
        guard !didChooseNext else { return }
        didChooseNext = true
        Analytics.track(AnalyticsEvent.nextChallengeChosen, ["option": "restart_harder"])
        launch(restartIntent)
    }
}

/// Identifiable wrapper so the native share sheet presents via `.sheet(item:)`.
struct CompletionSharePayload: Identifiable {
    let image: UIImage
    let id = UUID()
}
