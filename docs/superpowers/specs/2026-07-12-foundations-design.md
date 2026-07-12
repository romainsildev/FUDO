# FUDO — Foundations (Session 0) — Design Spec

> Date: 2026-07-12 · Status: approved by Romain · Scope: FOUNDATIONS ONLY.
> Sources of truth: `CLAUDE.md`, `docs/DATA-MODEL.md`, `project/build/STRUCTURE.md` (brain), `project/prd/12-navigation-ux-v2.md` (brain).
> This session builds the shell + design system + config + nav conventions. **No feature logic, no feature screens, no onboarding, no @Model entities, no third-party deps.**

---

## 1. Goal

Stand up the project skeleton every later session plugs into: canonical folder tree, the design-system token layer, the single game-config file, the sensei asset indirection, a custom floating-pill `TabView` with 4 tabs, and the navigation conventions encoded as reusable enums/modifiers so no future session can violate them.

Decisions taken (2026-07-12):
- **Structure = canonical `STRUCTURE.md`** (superset of the prompt's list): adds `Stats`, `Completion`, `Share` features, `Core/Extensions/`, `Core/Navigation/`, and `App/RootView`+`MainTabView`+`AppState`.
- **Models = minimal**: `Core/Models/SharedTypes.swift` only (enums + Codable structs). The 4 `@Model` entities and `.modelContainer` wiring are deferred to the data-layer session.
- **`GameConfig` values byte-identical to `docs/DATA-MODEL.md` §3, forever.** DATA-MODEL is the single source. Consequence: **rank thresholds are NOT in GameConfig** — they live in `Rank.floorOVR` per DATA-MODEL §2.

## 2. In scope / out of scope

**In:** folder tree; `Colors/Typography/Spacing/AppAnimation/Haptics`; `GameConfig`; `SharedTypes` (incl. `Rank`); `SenseiAssetProvider`; floating-pill `MainTabView` + hide-on-push; nav toolkit (`FudoSheet`/`FudoCover`/`FudoAlerts`/`FudoNavigationStack`/`TabBarVisibility`); thin `AppState` router + `RootView` seam; 9 styled placeholder views; project-setting fixes; Bebas Neue verification + DEBUG assertion.

**Out (do NOT build):** any feature logic; `@Model` entities; `OVREngine`/`RolloverService`/`DecayService`/`RankLadder`/`GameStore`; services (`Persistence`, `Notification`, `Entitlement`, `ShareCardRenderer`, `Review`); RevenueCat/PostHog; widget target; onboarding; real components in `DesignSystem/Components/`.

## 3. File manifest (all under the synced `FUDO/` root)

Xcode uses `PBXFileSystemSynchronizedRootGroup` — files created on disk auto-join the target. No `.pbxproj` membership edits.

### App/
| File | Responsibility |
|---|---|
| `FUDOApp.swift` | `@main`. Body → `RootView`, `.preferredColorScheme(.dark)`. DEBUG font assertion at launch (see §7). No `.modelContainer` yet. Currently at `FUDO/FUDOApp.swift`; **served** move to `App/`. |
| `RootView.swift` | Routing seam. Reads `AppState` → onboarding cover → paywall cover → `MainTabView`. For now all flags default so it lands on `MainTabView`. Covers wired via `.fudoCover` bound to placeholder destinations. |
| `MainTabView.swift` | Custom floating-pill container. 4 tabs, each a `FudoNavigationStack` wrapping the feature placeholder. Hosts the `FudoTabBar` overlay + hide-on-push. |
| `AppState.swift` | `@Observable` **thin router — routing flags only, ZERO logic** (§6). |

### Core/Models/
| File | Responsibility |
|---|---|
| `SharedTypes.swift` | `Rank`, `ChallengePreset`, `ChallengeStatus`, `TaskCheck`, `OVRPoint`. Plain enums / `Codable` structs — **no SwiftData import**. Verbatim from DATA-MODEL §2. |

### Core/Game/
| File | Responsibility |
|---|---|
| `GameConfig.swift` | Every tunable, **byte-identical to DATA-MODEL §3** (§5). |

### Core/DesignSystem/
| File | Responsibility |
|---|---|
| `Colors.swift` | All CLAUDE.md tokens via `Color(hex:)`. No hex ever appears in a view. |
| `Typography.swift` | SF Pro Display/Text scale; giant OVR style `.monospacedDigit()`; `onboardingDisplay` = `Font.custom("BebasNeue-Regular")`, **onboarding-only** (doc-commented). |
| `Spacing.swift` | Layout constants (§5). |
| `AppAnimation.swift` | Single curve source: `standard = .easeInOut(0.5)`, `slow = .easeInOut(0.6)`. Nothing faster is exposed. |
| `Haptics.swift` | `light/medium/heavy/success`. Doc: primary buttons, validations, onboarding transitions ONLY. |
| `SenseiAssetProvider.swift` | `Rank → (imageName, stateDescription)`. Points at committed imagesets, SF-Symbol fallback (§8). |
| `Components/` | **Empty this session** (git won't track empty dirs → folder appears with its first real component later). |

### Core/Navigation/ (nav conventions, single source — prd/12 §1)
| File | Responsibility |
|---|---|
| `FudoTabBar.swift` | The floating pill view. Dark capsule bg + 1px border; **every tab = icon + label**; active tab = vermillon icon+label inside a filled highlight; inactive = grey (per DesignReference/app 01/02/05/07). |
| `FudoNavigationStack.swift` | Reusable wrapper: `NavigationStack` bound to a path; hides the pill whenever the path is non-empty. Every push obeys automatically. |
| `TabBarVisibility.swift` | `@Observable` visibility state in the environment + `.fudoHidesTabBar()` manual override modifier. |
| `FudoSheet.swift` | `enum FudoSheet { flame, reminderTime, shareCard }` + `.fudoSheet(item:)` → detent `.medium`, grabber, swipe-down. |
| `FudoCover.swift` | `enum FudoCover { onboarding, paywall, challengeSetup, challengeComplete, rankUp }` + `.fudoCover(item:)` → `fullScreenCover`, no gesture dismiss. |
| `FudoAlerts.swift` | `.fudoDestructiveConfirm(...)` two-step (abandon, delete data); `.fudoSimpleAlert(...)` (uncheck). |

### Core/Extensions/
| File | Responsibility |
|---|---|
| `Color+Hex.swift` | `Color(hex:)` init used by `Colors.swift`. |

### Features/ (each: `Views/<Name>PlaceholderView.swift`)
`Onboarding`, `Paywall`, `ChallengeSetup`, `Home`, `Progression`, `Stats`, `Completion`, `Share`, `Settings` — 9 dark, token-styled placeholders naming their screen. The 4 tab placeholders (`Home`=Today, `Progression`=Progress, `Stats`, `Settings`) carry a temporary, clearly-labeled "push demo" row that pushes a sub-placeholder to **prove the pill hides on push**. All replaced by real screens in later sessions.

## 4. Navigation conventions (encoded, not just documented)

Per prd/12 §1 — the toolkit makes violations hard:
- **Tab switch** between the 4 destinations only. `MainTabView` owns `selectedTab`. Never a cross-tab push.
- **Sheet** (`.fudoSheet`): detent `.medium`, grabber, swipe-down — flame, reminder time picker, share card.
- **Push** (`FudoNavigationStack`): native back, **pill hidden** — habit detail, Settings subscreens. Hiding is built in now.
- **Cover** (`.fudoCover`): full screen, no gesture dismiss — onboarding, paywall, standalone challenge setup, challenge complete, rank-up.
- **Destructive = two-step alert** (`.fudoDestructiveConfirm`); simple alert (`.fudoSimpleAlert`) = uncheck.

**Pill hide-on-push mechanism:** the pill is an overlay above the selected tab's `FudoNavigationStack`; it is visible ⟺ that tab's `NavigationPath` is empty. Animated with `AppAnimation.standard`. `.fudoHidesTabBar()` is an escape hatch for screens that must force-hide independent of path depth.

## 5. Exact constant values

### GameConfig.swift — byte-identical to DATA-MODEL §3 (reproduce verbatim, including comments)
```swift
enum GameConfig {
    static let ovrMax = 99.0
    static let baseOVRMin = 40, baseOVRMax = 50
    static let dailyRate = 0.033          // taux de convergence par journée 100 %
    static let penaltyFactor = 2.0        // pénalité = 2 × gain potentiel du jour
    static let penaltyMin = 2.0           // pénalité plancher (visible même à haut OVR)
    static let graceHours = 2             // rollover à 2 h du matin, silencieux
    static let decayStartDays = 7         // sans défi actif
    static let decayIntervalDays = 3      // -1 tous les 3 jours
    static let decayAmount = 1.0
    static let maxRules = 8
    static let rulesLockDay = 3
}
```
No additions. The daily-pool formula and rank thresholds are NOT here (engine / Rank respectively).

### Rank (in SharedTypes.swift) — DATA-MODEL §2
Thresholds live here, not in GameConfig:
- Cases: `novice, disciple, ascetic, warrior, master, sensei` (Int raw 0…5).
- `floorOVR`: `[0, 50, 60, 70, 80, 90][rawValue]` (decay floor).
- `static func from(ovr:) -> Rank`: switch on 0-49 / 50-59 / 60-69 / 70-79 / 80-89 / 90-99.

### Colors.swift — CLAUDE.md tokens
`bgPrimary #121110` · `bgCard #1C1A17` · `border #2A2724` · `textPrimary #FAF0E6` · `textSecondary #A89F92` · `accent #E34234` · `accentPressed #FF5140` · `accentDeep #7A1F17` · `positive #34C759` · `negative #FF453A` · `celebrationGold #E8B44A`.

### Spacing.swift — CLAUDE.md
`screenMargin 20` · `cardPadding 16` · `cardPaddingMajor 20` · `sectionGap 40` · `radiusCard 24` (`.rect(cornerRadius:style:.continuous)`) · `radiusNested 8` · `ctaHeight 56` · `ringWidth 6` (lineCap `.round`).

## 6. AppState — thin router (addition #2)

`AppState` holds **routing flags only, no business logic, no persistence, no game math**:
```
hasCompletedOnboarding: Bool   // seam → later read from UserDefaults / onboarding
entitlementActive: Bool        // SEAM (Session 6 EntitlementStore drives this)
hasActiveChallenge: Bool       // SEAM (Session 1 GameStore drives this)
selectedTab: Tab               // Today/Progress/Stats/Settings
```
`RootView` derives the route purely from these flags. **Seam contract:** later stores own real state and assign into these flags (e.g. `appState.hasActiveChallenge = gameStore.activeChallenge != nil`); `AppState` never grows logic. Each flag carries a `// SEAM (Session N …)` comment. Defaults this session route to `MainTabView` (onboarding done, entitled, no active challenge).

## 7. Bebas Neue (addition #1)

- Font file present: `FUDO/Resources/Fonts/BebasNeue-Regular.ttf`. **PostScript name = `BebasNeue-Regular`** (verified from the `name` table).
- `UIAppFonts` already declares `BebasNeue-Regular.ttf` in `FUDO/Info.plist`. While in the pbxproj/build settings: **verify** it survives (do not duplicate the key — `GENERATE_INFOPLIST_FILE = YES` merges the manual plist).
- `Typography.onboardingDisplay` = `Font.custom("BebasNeue-Regular", size:)` — must resolve to the real face, never a silent system fallback.
- **DEBUG-only launch assertion** in `FUDOApp.init()`:
  `assert(UIFont(name: "BebasNeue-Regular", size: 17) != nil, "Bebas Neue not registered — check UIAppFonts + Resources/Fonts")`.

## 8. SenseiAssetProvider (addition — real art exists)

Real art already committed: `sensei-1-novice … sensei-6-sensei` imagesets + `enso-100`. Provider returns the real image name per rank + a short state description, with an SF-Symbol fallback so a missing asset never breaks a call site (honours "swap art without touching call sites"):

| Rank | imageName | state description |
|---|---|---|
| novice | `sensei-1-novice` | hooded, seated |
| disciple | `sensei-2-disciple` | standing |
| ascetic | `sensei-3-ascetic` | guard stance + faint aura |
| warrior | `sensei-4-warrior` | clear aura + staff |
| master | `sensei-5-master` | wide aura |
| sensei | `sensei-6-sensei` | final iconic form |

API: `SenseiAssetProvider.image(for: Rank) -> Image` (Asset if present else SF-Symbol fallback) + `description(for: Rank) -> String`. Single indirection point.

## 9. Project-setting fixes (`.pbxproj`, Debug + Release)

| Setting | From | To | Why |
|---|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.5` | `17.0` | CLAUDE.md/task: iOS 17 min (26.5 was the Xcode-shell default). |
| `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` | Portrait+Landscape×2 | `UIInterfaceOrientationPortrait` | Portrait only. |
| `TARGETED_DEVICE_FAMILY` | `1,2` | `1` | iPhone only. |
| `AccentColor` asset | default | `#E34234` | System accent = vermillon. |

Leave `SWIFT_VERSION = 5.0`. Verify Bebas Neue `UIAppFonts` intact (§7).

## 10. Served commands (Romain runs — never executed autonomously, per hygiene rule)

```
git mv FUDO/FUDOApp.swift FUDO/App/FUDOApp.swift   # relocate entry point into App/
git rm FUDO/ContentView.swift                       # replaced by RootView + MainTabView
```
Everything else is created in place; the app compiles at every intermediate step (I rewrite `FUDOApp.swift` before serving the move).

## 11. Verification

- `xcodebuild -scheme FUDO -destination 'generic/platform=iOS Simulator' build` must succeed (no signing needed for simulator).
- Launch in simulator: 4 tabs render, dark forced, portrait locked, pill floats, active tab = vermillon capsule, tapping a "push demo" hides the pill and native back restores it.
- DEBUG font assertion does not trip.

## 12. Open flags (Romain confirms visually)

- **Pill look** built to `DesignReference/app/{01-home,02-progression,05-stats,07-settings}.png` (authoritative mockup per CLAUDE.md): dark floating capsule, every tab icon+label, active = vermillon content + filled highlight (`accent.opacity(0.15)`), inactive = `textSecondary`. Icons Today=house / Progress=bars / Stats=line / Settings=gear. Highlight tint + insets are Romain's visual-confirm in the simulator.
- Placeholder "push demo" rows are temporary scaffolding to prove hide-on-push; removed as real screens land.
