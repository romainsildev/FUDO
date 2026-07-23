import Foundation
import PostHog

/// Product analytics wrapper (ANALYTICS-PLAN.md). The ONE seam to PostHog:
/// every call site goes through `Analytics`, never `PostHogSDK` directly, so the
/// backend can be cut or mocked in one place. DEBUG builds get `NoopAnalytics` —
/// zero capture, so dev/seed data never pollutes the funnels. Anonymous strict:
/// no `identify()`, no email/name (no accounts), never the exact age or any
/// free text — only bracketed / enum values reach the network (plan §4).
protocol AnalyticsClient {
    func track(_ event: String, properties: [String: Any]?)
    /// $set person properties on the anonymous user (no identify).
    func set(person: [String: Any])
}

/// The facade every feature uses. `configure()` picks the backend once at launch.
enum Analytics {
    private static var client: AnalyticsClient = NoopAnalytics()

    /// Called once at launch (FUDOApp). Release wires PostHog with lifecycle
    /// autocapture ON (the download→trial denominator) and everything else OFF;
    /// DEBUG stays a no-op.
    static func configure() {
        #if DEBUG
        client = NoopAnalytics()
        #else
        // `projectToken:` is the current label for the public phc_ key
        // (posthog-ios renamed `apiKey:`, now deprecated). Same value, same host.
        let config = PostHogConfig(projectToken: AppConfig.postHogAPIKey, host: AppConfig.postHogHost)
        // Keep Installed / Opened firing — they anchor retention (plan §1.1).
        config.captureApplicationLifecycleEvents = true
        // Everything else off: no autocaptured screen views, no session replay.
        config.captureScreenViews = false
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)
        client = PostHogAnalytics()
        #endif
    }

    static func track(_ event: String, _ properties: [String: Any]? = nil) {
        client.track(event, properties: properties)
    }

    static func set(person: [String: Any]) {
        client.set(person: person)
    }
}

/// Captures nothing — the DEBUG backend and the default until `configure()` runs.
struct NoopAnalytics: AnalyticsClient {
    func track(_ event: String, properties: [String: Any]?) {}
    func set(person: [String: Any]) {}
}

/// Real backend. The only type that touches the PostHog SDK. Compiled in every
/// config so the API stays type-checked, but only selected by `configure()` in
/// Release — DEBUG never calls `setup`, so PostHog stays dormant (zero capture).
struct PostHogAnalytics: AnalyticsClient {
    func track(_ event: String, properties: [String: Any]?) {
        PostHogSDK.shared.capture(event, properties: properties)
    }
    func set(person: [String: Any]) {
        // Anonymous $set — no identify, no distinct id of our own.
        PostHogSDK.shared.capture("$set", properties: nil, userProperties: person)
    }
}

/// Every event name, once (plan §1). snake_case, verb in the past tense.
/// No event string is typed twice anywhere in the app.
enum AnalyticsEvent {
    // Onboarding funnel (§1.2)
    static let onboardingScreenViewed = "onboarding_screen_viewed"
    static let onboardingQuestionAnswered = "onboarding_question_answered"
    static let onboardingChallengeComposed = "onboarding_challenge_composed"
    static let onboardingProjectionViewed = "onboarding_projection_viewed"
    static let onboardingFirstCheckDone = "onboarding_first_check_done"
    static let reviewPromptRequested = "review_prompt_requested"
    static let notifPermissionAnswered = "notif_permission_answered"
    static let onboardingCompleted = "onboarding_completed"

    // Paywall (§1.3)
    static let paywallViewed = "paywall_viewed"
    static let paywallPlanSelected = "paywall_plan_selected"
    static let paywallDismissed = "paywall_dismissed"
    static let paywallProductsFailed = "paywall_products_failed"
    static let trialStarted = "trial_started"
    static let purchaseCompleted = "purchase_completed"
    static let purchaseFailed = "purchase_failed"
    static let purchaseRestored = "purchase_restored"
    static let subscriptionExpired = "subscription_expired"

    // Activation + retention (§1.4 / §1.5) — all fired from GameStore
    static let challengeStarted = "challenge_started"
    static let taskChecked = "task_checked"
    static let taskUnchecked = "task_unchecked"
    static let dayCompleted = "day_completed"
    static let dayFailed = "day_failed"
    static let streakMilestone = "streak_milestone"
    static let rankUp = "rank_up"

    // Engagement (§1.8)
    static let flameSheetViewed = "flame_sheet_viewed"
    static let statsViewed = "stats_viewed"
    static let statsPeriodChanged = "stats_period_changed"
    static let habitDetailViewed = "habit_detail_viewed"

    // Widget (P7) — fired from the app on foreground when the installed families change.
    static let widgetDetected = "widget_detected"
}

/// Anonymizes a habit into a stable slug for `habit_detail_viewed` (plan §1.8):
/// preset rules are identified by their SF Symbol (the stable identity — titles
/// carry baked values and user text), anything else is `custom_<index>`. The
/// user-typed title NEVER leaves the device.
enum AnalyticsHabit {
    private static let presetSlugs: [String: String] = [
        "figure.strengthtraining.traditional": "daily_workout",
        "drop.fill": "cold_shower",
        "book.fill": "read",
        "iphone.slash": "social_cap",
        "sunrise.fill": "wake_up",
        "figure.mind.and.body": "meditate",
        "wineglass": "no_alcohol",
        "square.and.pencil": "journal",
    ]

    static func slug(iconName: String, index: Int) -> String {
        presetSlugs[iconName] ?? "custom_\(index)"
    }
}
