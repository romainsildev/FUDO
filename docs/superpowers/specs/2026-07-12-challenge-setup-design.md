# Challenge Setup — Design (2026-07-12, approved by Romain)

Three skins, one view model. Feature dir: `FUDO/Features/ChallengeSetup/`.

## Decisions (Romain, this session)

1. **Entry points**: Home no-challenge CTA (and later Challenge-complete) present the
   **standalone frame-04 cover** only. The full 3-screen flow is built as a reusable
   component with **no in-app entry yet** (onboarding will host the inline variant later).
2. **Day 1 = today**: GameStore unchanged (startDate = today's effective day). Frame-04
   CTA copy corrected to "Start challenge — Day 1" (frame said "Day 1 tomorrow").
3. **Rule values baked into title**: wake-up time edited via time picker writes the
   formatted time into the title string ("Wake up before 07:00"). No schema change.
4. **Reminder in standalone**: silent default 07:00 (420 min), no picker (matches frame).
   Full-flow screen 3 keeps the time picker.
5. **Chips vs presets divergence** (STATE 2026-07-11): maquette followed — standalone
   uses duration chips 30/60/75/90. Logged; Romain approved the design containing it.
6. Editing a preset's rules does NOT flip `preset` to `.custom` — the chosen preset is
   kept (records intent). `.custom` reserved for a future custom path.
7. Switching preset/chip **reloads that preset's default rules, discarding edits**.

## Shared core

- `PresetCatalog.swift` — static `PresetDefinition { preset, days, title, tagline,
  defaultRules }`:
  - **Monk Mode 30** (30 d, "The standard entry."): Daily workout · Cold shower ·
    Read 30 min · Social media under 1h · Wake up before 07:00 (time-editable).
  - **Monk Mode 60** (60 d, "The real reset."): same + Meditate 10 min.
  - **Hardcore 90** (90 d, "Elite. Brutal by design."): everything + No alcohol ·
    One-line journal.
  - **The Classic 75** (75 d): Two workouts · Diet held · Read 10 pages · Water goal ·
    Progress photo (**ships toggle-OFF** = the "optional"). The words "75 Hard" appear
    NOWHERE (trademark).
  - `RuleIconCatalog` — curated ~16 SF Symbols for the icon picker.
- `EditableRule` — Identifiable value type: id, title, iconName, isEnabled, domain
  (settable in code, **no domain UI**), `valueKind` (.none | .time(Date)). Custom rules
  are plain text + icon.
- `ChallengeSetupViewModel` — `@Observable`, `init(recommendedPreset: ChallengePreset
  = .monk30)`. Owns selectedPreset, rules (add/delete/toggle/edit, cap
  `GameConfig.maxRules` = 8), `showRuleCountWarning` (≥7 enabled → "More rules = more
  failure."), reminderMinutes (default 420), recap (exact end date, starting OVR),
  `canCommit` (≥1 enabled rule). `commit(store:)` maps ENABLED rules → `RuleDraft` →
  `GameStore.startChallenge`. Views never compute presets/rules themselves.

## Skin (c) — standalone cover (frame 04) — wired to Home NOW

`ChallengeSetupStandaloneView`: back chevron + "New challenge" header (no progress bar)
· eyebrow "YOUR PROTOCOL" (accent) · "Your Monk Mode. Your rules." · duration chips
30/60/75/90 → monk30/monk60/classic75/hardcore90 · section line
"<PRESET> · RECOMMENDED FOR YOU" in `FudoColor.positive` (frame uses green — flagged
exception to "no green accent UI") shown on the recommended preset only · rule rows
(tap → edit sheet, trailing toggle) · dashed "＋ Add rule" ghost row · warning line from
7th rule · caption "Tap a rule to adjust it. This is YOUR protocol." · CTA =
`HoldToConfirm`, label "Start challenge — Day 1", heavy haptic → startChallenge →
dismiss → Home day 1. fullScreenCover, no gesture dismiss, back = only exit.
Home's `challengeSetupStub` replaced by the real view.

## Skin (a) — full flow (built, dormant)

`ChallengeSetupFlowView` (own NavigationStack):
1. `PresetPickerScreen` — vertical preset cards, "Recommended for you" badge on the
   injected preset, taglines above.
2. `RulesEditorScreen` — same shared rows/sheet/add-row.
3. `LaunchConfirmScreen` — recap (duration, rules list, exact end date, starting OVR,
   reminder time picker default 07:00) + verbatim failure rule: "Incomplete day = your
   OVR drops. The challenge goes on. No reset. No excuses." CTA = HoldToConfirm
   "Hold to commit.", heavy haptic.

## Skin (b) — inline onboarding (OB 11)

NOT built this session (Onboarding is a placeholder). The VM + shared row components
are the contract; the inline skin ships with the onboarding session.

## Shared components

`RuleRowEditor`, `RuleEditSheet` (title field; time picker when `.time`; icon grid),
`AddRuleRow`, `DurationChip`, `PresetCard`.

## Model

Add `Challenge.canEditRules(now:calendar:)` = `!isRuleEditingLocked(...)` — editing
allowed until day 3 inclusive (`GameConfig.rulesLockDay`); Settings consumes later.

## Guards / out of scope

Only one active challenge (Home already guards; `startChallenge` double-guards).
No paywall logic. Abandon lives in Settings only. No recurrence, no domain UI.

## Tests

`ChallengeSetupViewModelTests` — pure logic, no SwiftData container: preset load, chip
mapping, 8-cap, warning at 7, enabled-only commit mapping, end-date math. Run = Romain
(Cmd+U). Session verification = compile-only build.
