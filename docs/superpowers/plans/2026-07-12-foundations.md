# FUDO Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the FUDO project skeleton — canonical folder tree, design-system tokens, single game-config file, sensei asset indirection, a custom floating-pill 4-tab shell, and navigation conventions encoded as reusable enums/modifiers — with nothing feature-specific built.

**Architecture:** SwiftUI + `@Observable`, iOS 17+. Design-system tokens are plain enums (`FudoColor`/`FudoFont`/`FudoSpacing`/`AppAnimation`/`Haptics`). Game constants live in one `GameConfig` (byte-identical to `docs/DATA-MODEL.md` §3); rank thresholds live in `Rank`. The tab shell is a stock `TabView` with its bar hidden, overlaid by a custom `FudoTabBar` pill whose visibility is driven by the selected tab's `NavigationPath` depth (push ⇒ pill hides). Nav conventions are reusable modifiers (`.fudoSheet`, `.fudoCover`, `.fudoDestructiveConfirm`). `AppState` is a thin routing-flag holder; real state plugs in behind its flags later.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing (`import Testing`), `xcodebuild`. No third-party dependencies at this stage.

## Global Constraints

- **Working dir (all commands):** `/Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO`
- **iOS 17.0 minimum.** SwiftUI only. `@Observable` (never `ObservableObject`). No third-party deps.
- **Dark only:** `.preferredColorScheme(.dark)` forced; no light-mode logic.
- **Portrait, iPhone only.**
- **No hex literal in any view** — colors come from `FudoColor` tokens only.
- **`GameConfig` byte-identical to `docs/DATA-MODEL.md` §3, forever.** DATA-MODEL is the single source. Rank thresholds are NOT in GameConfig (they live in `Rank.floorOVR`).
- **Animations `.easeInOut` 0.4–0.6 s only.** Nothing faster is exposed by `AppAnimation`.
- **Haptics** only via `Haptics.{light,medium,heavy,success}` — used on primary buttons, validations, onboarding transitions; nowhere else.
- **Bebas Neue** PostScript name = `BebasNeue-Regular`; onboarding display ONLY, never app UI.
- **UI strings EN.** Code + file names EN.
- **Hygiene:** never delete/move a file autonomously — file removals/moves are *served* to Romain as commands. Never leave a build-broken intermediate.
- **Xcode uses `PBXFileSystemSynchronizedRootGroup`** — files created on disk under `FUDO/` auto-join the target; no `.pbxproj` membership editing.

**Build command (used throughout):**
```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
xcodebuild -project FUDO.xcodeproj -scheme FUDO \
  -destination 'generic/platform=iOS Simulator' build
```
**Test command (used throughout):** replace `iPhone 16` with an available sim from `xcrun simctl list devices available`.
```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
xcodebuild -project FUDO.xcodeproj -scheme FUDO \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

### Task 1: Project settings + accent color

**Files:**
- Modify: `FUDO.xcodeproj/project.pbxproj` (build settings, all configs)
- Modify: `FUDO/Assets.xcassets/AccentColor.colorset/Contents.json`

**Interfaces:**
- Consumes: nothing.
- Produces: deployment target 17.0, portrait-iPhone-only, `AccentColor` = `#E34234`.

- [ ] **Step 1: Edit build settings in `project.pbxproj`** — replace ALL occurrences:
  - `IPHONEOS_DEPLOYMENT_TARGET = 26.5;` → `IPHONEOS_DEPLOYMENT_TARGET = 17.0;`
  - `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";` → `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait";`
  - `TARGETED_DEVICE_FAMILY = "1,2";` → `TARGETED_DEVICE_FAMILY = "1";`

  Leave `SWIFT_VERSION`, `GENERATE_INFOPLIST_FILE`, `INFOPLIST_FILE`, and the `_iPad` orientation key untouched.

- [ ] **Step 2: Set `AccentColor` to `#E34234`** — overwrite `FUDO/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.204",
          "green" : "0.259",
          "red" : "0.890"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Verify build settings applied**

Run:
```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
xcodebuild -project FUDO.xcodeproj -scheme FUDO -showBuildSettings 2>/dev/null | \
  grep -E "IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|UISupportedInterfaceOrientations_iPhone"
```
Expected: `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `TARGETED_DEVICE_FAMILY = 1`, iPhone orientations = `UIInterfaceOrientationPortrait`.

- [ ] **Step 4: Verify Bebas Neue still declared** (do NOT duplicate the key)

Run:
```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
plutil -p FUDO/Info.plist | grep -A2 UIAppFonts
```
Expected: array contains `"BebasNeue-Regular.ttf"`.

- [ ] **Step 5: Build to confirm project still compiles**

Run the Build command (Global Constraints). Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO.xcodeproj/project.pbxproj FUDO/Assets.xcassets/AccentColor.colorset/Contents.json
git commit -m "chore: iOS 17 target, portrait iPhone-only, vermillon accent"
```

---

### Task 2: Color(hex:) + design-system color tokens

**Files:**
- Create: `FUDO/Core/Extensions/Color+Hex.swift`
- Create: `FUDO/Core/DesignSystem/Colors.swift`
- Test: `FUDOTests/ColorsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `Color(hex: String)`; `enum FudoColor` with static `Color` tokens `bgPrimary, bgCard, border, textPrimary, textSecondary, accent, accentPressed, accentDeep, positive, negative, celebrationGold`.

- [ ] **Step 1: Write the failing test** — `FUDOTests/ColorsTests.swift`:

```swift
import Testing
import SwiftUI
import UIKit
@testable import FUDO

struct ColorsTests {
    private func rgb(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    @Test func hexParsesToComponents() {
        let c = rgb(Color(hex: "E34234"))
        #expect(abs(c.r - 0.890) < 0.01)
        #expect(abs(c.g - 0.259) < 0.01)
        #expect(abs(c.b - 0.204) < 0.01)
    }

    @Test func accentTokenIsVermillon() {
        let a = rgb(FudoColor.accent)
        let hex = rgb(Color(hex: "E34234"))
        #expect(abs(a.r - hex.r) < 0.001)
        #expect(abs(a.g - hex.g) < 0.001)
        #expect(abs(a.b - hex.b) < 0.001)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — `Color(hex:)` / `FudoColor` not defined (compile error).

- [ ] **Step 3: Create `FUDO/Core/Extensions/Color+Hex.swift`**

```swift
import SwiftUI

extension Color {
    /// Hex string ("E34234" or "#E34234") → sRGB Color, opacity 1.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
```

- [ ] **Step 4: Create `FUDO/Core/DesignSystem/Colors.swift`**

```swift
import SwiftUI

/// Design-system color tokens (CLAUDE.md). Never hardcode a hex in a view.
/// Each token must be mirrored in the Asset Catalog under the same name when
/// the widget target is added (widget can't read Swift tokens).
enum FudoColor {
    static let bgPrimary = Color(hex: "121110")   // warm ink black
    static let bgCard = Color(hex: "1C1A17")
    static let border = Color(hex: "2A2724")      // 1px on every card, never a shadow

    static let textPrimary = Color(hex: "FAF0E6") // never pure white
    static let textSecondary = Color(hex: "A89F92")

    static let accent = Color(hex: "E34234")       // vermillon — CTA, rings, flame, ensō, bars
    static let accentPressed = Color(hex: "FF5140")
    static let accentDeep = Color(hex: "7A1F17")   // rank-badge backgrounds

    static let positive = Color(hex: "34C759")     // OVR delta ▲ only
    static let negative = Color(hex: "FF453A")     // OVR delta ▼ only

    static let celebrationGold = Color(hex: "E8B44A") // celebration bursts only
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run the Test command. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/Extensions/Color+Hex.swift FUDO/Core/DesignSystem/Colors.swift FUDOTests/ColorsTests.swift
git commit -m "feat: color tokens + Color(hex:)"
```

---

### Task 3: Spacing, AppAnimation, Haptics

**Files:**
- Create: `FUDO/Core/DesignSystem/Spacing.swift`
- Create: `FUDO/Core/DesignSystem/AppAnimation.swift`
- Create: `FUDO/Core/DesignSystem/Haptics.swift`
- Test: `FUDOTests/DesignConstantsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum FudoSpacing` (`screenMargin, cardPadding, cardPaddingMajor, sectionGap, radiusCard, radiusNested, ctaHeight, ringWidth: CGFloat`); `enum AppAnimation` (`standard, slow: Animation`); `enum Haptics` (`light(), medium(), heavy(), success()`).

- [ ] **Step 1: Write the failing test** — `FUDOTests/DesignConstantsTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import FUDO

struct DesignConstantsTests {
    @Test func spacingTokens() {
        #expect(FudoSpacing.screenMargin == 20)
        #expect(FudoSpacing.cardPadding == 16)
        #expect(FudoSpacing.cardPaddingMajor == 20)
        #expect(FudoSpacing.sectionGap == 40)
        #expect(FudoSpacing.radiusCard == 24)
        #expect(FudoSpacing.radiusNested == 8)
        #expect(FudoSpacing.ctaHeight == 56)
        #expect(FudoSpacing.ringWidth == 6)
    }
}
```

> `Haptics` has no headless-verifiable behavior — it is covered by compilation (used by `FudoTabBar` in Task 8), not a unit test. Do not add an assertion-less "smoke" test.

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — `FudoSpacing` not defined (compile error).

- [ ] **Step 3: Create `FUDO/Core/DesignSystem/Spacing.swift`**

```swift
import CoreGraphics

/// Layout constants (CLAUDE.md). Card corners use `.rect(cornerRadius:style:.continuous)`.
enum FudoSpacing {
    static let screenMargin: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardPaddingMajor: CGFloat = 20
    static let sectionGap: CGFloat = 40
    static let radiusCard: CGFloat = 24
    static let radiusNested: CGFloat = 8
    static let ctaHeight: CGFloat = 56   // primary CTA = Capsule, height 56
    static let ringWidth: CGFloat = 6    // lineCap .round
}
```

- [ ] **Step 4: Create `FUDO/Core/DesignSystem/AppAnimation.swift`**

```swift
import SwiftUI

/// Single source for motion curves. Slow = premium: nothing faster than 0.4 s
/// is exposed. Always ease-in-out.
enum AppAnimation {
    static let standard = Animation.easeInOut(duration: 0.5)
    static let slow = Animation.easeInOut(duration: 0.6)
}
```

- [ ] **Step 5: Create `FUDO/Core/DesignSystem/Haptics.swift`**

```swift
import UIKit

/// Haptic helpers. Use ONLY on primary buttons, validations (hold-to-check),
/// and onboarding transitions — nowhere else.
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run the Test command. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/DesignSystem/Spacing.swift FUDO/Core/DesignSystem/AppAnimation.swift FUDO/Core/DesignSystem/Haptics.swift FUDOTests/DesignConstantsTests.swift
git commit -m "feat: spacing, animation, haptics tokens"
```

---

### Task 4: SharedTypes (Rank + enums + Codable structs)

**Files:**
- Create: `FUDO/Core/Models/SharedTypes.swift`
- Test: `FUDOTests/RankTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct TaskCheck`, `struct OVRPoint`, `enum ChallengePreset`, `enum ChallengeStatus`, `enum Rank: Int, CaseIterable` with `var floorOVR: Double` and `static func from(ovr: Double) -> Rank`.

- [ ] **Step 1: Write the failing test** — `FUDOTests/RankTests.swift`:

```swift
import Testing
import Foundation
@testable import FUDO

struct RankTests {
    @Test func sixRanksInOrder() {
        #expect(Rank.allCases == [.novice, .disciple, .ascetic, .warrior, .master, .sensei])
    }

    @Test func fromOVRBoundaries() {
        #expect(Rank.from(ovr: 0) == .novice)
        #expect(Rank.from(ovr: 49.9) == .novice)
        #expect(Rank.from(ovr: 50) == .disciple)
        #expect(Rank.from(ovr: 59.9) == .disciple)
        #expect(Rank.from(ovr: 60) == .ascetic)
        #expect(Rank.from(ovr: 69.9) == .ascetic)
        #expect(Rank.from(ovr: 70) == .warrior)
        #expect(Rank.from(ovr: 79.9) == .warrior)
        #expect(Rank.from(ovr: 80) == .master)
        #expect(Rank.from(ovr: 89.9) == .master)
        #expect(Rank.from(ovr: 90) == .sensei)
        #expect(Rank.from(ovr: 99) == .sensei)
    }

    @Test func floorOVRPerRank() {
        #expect(Rank.novice.floorOVR == 0)
        #expect(Rank.disciple.floorOVR == 50)
        #expect(Rank.ascetic.floorOVR == 60)
        #expect(Rank.warrior.floorOVR == 70)
        #expect(Rank.master.floorOVR == 80)
        #expect(Rank.sensei.floorOVR == 90)
    }

    @Test func taskCheckRoundTrips() throws {
        let original = TaskCheck(ruleID: UUID(), checkedAt: Date(timeIntervalSince1970: 1000), ovrDelta: 0.4)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskCheck.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — `Rank` / `TaskCheck` not defined.

- [ ] **Step 3: Create `FUDO/Core/Models/SharedTypes.swift`**

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run the Test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/Models/SharedTypes.swift FUDOTests/RankTests.swift
git commit -m "feat: shared types + Rank ladder"
```

---

### Task 5: GameConfig (byte-identical to DATA-MODEL §3)

**Files:**
- Create: `FUDO/Core/Game/GameConfig.swift`
- Test: `FUDOTests/GameConfigTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum GameConfig` with the exact constants below.

- [ ] **Step 1: Write the failing test** — `FUDOTests/GameConfigTests.swift`:

```swift
import Testing
@testable import FUDO

struct GameConfigTests {
    @Test func constantsMatchDataModel() {
        #expect(GameConfig.ovrMax == 99.0)
        #expect(GameConfig.baseOVRMin == 40)
        #expect(GameConfig.baseOVRMax == 50)
        #expect(GameConfig.dailyRate == 0.033)
        #expect(GameConfig.penaltyFactor == 2.0)
        #expect(GameConfig.penaltyMin == 2.0)
        #expect(GameConfig.graceHours == 2)
        #expect(GameConfig.decayStartDays == 7)
        #expect(GameConfig.decayIntervalDays == 3)
        #expect(GameConfig.decayAmount == 1.0)
        #expect(GameConfig.maxRules == 8)
        #expect(GameConfig.rulesLockDay == 3)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — `GameConfig` not defined.

- [ ] **Step 3: Create `FUDO/Core/Game/GameConfig.swift`** — reproduce DATA-MODEL §3 verbatim:

```swift
/// Single source of every gameplay constant. Byte-identical to docs/DATA-MODEL.md §3 — never diverge.
/// Rank thresholds are NOT here (they live in Rank.floorOVR). Never change without Romain's explicit approval.
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

- [ ] **Step 4: Run the test to verify it passes**

Run the Test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/Game/GameConfig.swift FUDOTests/GameConfigTests.swift
git commit -m "feat: GameConfig (verbatim from DATA-MODEL)"
```

---

### Task 6: Typography + Bebas Neue registration

**Files:**
- Create: `FUDO/Core/DesignSystem/Typography.swift`
- Test: `FUDOTests/TypographyTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum FudoFont` with `title(_:)`, `body(_:)`, `caption(_:)`, `ovr(_:)`, `onboardingDisplay(_:)` → `Font`.

- [ ] **Step 1: Write the failing test** — `FUDOTests/TypographyTests.swift`:

```swift
import Testing
import UIKit
@testable import FUDO

struct TypographyTests {
    @Test func bebasNeueIsRegistered() {
        // Host app registers UIAppFonts → the PostScript name must resolve.
        #expect(UIFont(name: "BebasNeue-Regular", size: 17) != nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — compile error (test references nothing new yet) OR the font is not registered. If the font assert already passes but `FudoFont` is unused, the file compiles; add `FudoFont` in Step 3 regardless (the type is required by later tasks).

- [ ] **Step 3: Create `FUDO/Core/DesignSystem/Typography.swift`**

```swift
import SwiftUI

/// App UI type = SF Pro (system). Bebas Neue = ONBOARDING display hooks ONLY — never in app UI.
enum FudoFont {
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold) }
    static func body(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .regular) }

    /// Giant OVR number — monospaced digits so it doesn't jitter while animating.
    static func ovr(_ size: CGFloat = 72) -> Font { .system(size: size, weight: .heavy).monospacedDigit() }

    /// ONBOARDING ONLY. Bebas Neue (PostScript name `BebasNeue-Regular`). Never call from app UI.
    static func onboardingDisplay(_ size: CGFloat = 48) -> Font { .custom("BebasNeue-Regular", size: size) }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run the Test command. Expected: PASS. If it FAILS (`UIFont(name:)` nil), the font is not reaching the bundle — confirm `FUDO/Resources/Fonts/BebasNeue-Regular.ttf` is in the target and `UIAppFonts` lists it; do NOT ship a system fallback.

- [ ] **Step 5: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/DesignSystem/Typography.swift FUDOTests/TypographyTests.swift
git commit -m "feat: typography scale + Bebas Neue registration test"
```

---

### Task 7: SenseiAssetProvider

**Files:**
- Create: `FUDO/Core/DesignSystem/SenseiAssetProvider.swift`
- Test: `FUDOTests/SenseiAssetProviderTests.swift`

**Interfaces:**
- Consumes: `Rank` (Task 4).
- Produces: `enum SenseiAssetProvider` with `imageName(for: Rank) -> String`, `description(for: Rank) -> String`, `image(for: Rank) -> Image`.

- [ ] **Step 1: Write the failing test** — `FUDOTests/SenseiAssetProviderTests.swift`:

```swift
import Testing
import UIKit
@testable import FUDO

struct SenseiAssetProviderTests {
    @Test func imageNamesMapToRanks() {
        #expect(SenseiAssetProvider.imageName(for: .novice) == "sensei-1-novice")
        #expect(SenseiAssetProvider.imageName(for: .disciple) == "sensei-2-disciple")
        #expect(SenseiAssetProvider.imageName(for: .ascetic) == "sensei-3-ascetic")
        #expect(SenseiAssetProvider.imageName(for: .warrior) == "sensei-4-warrior")
        #expect(SenseiAssetProvider.imageName(for: .master) == "sensei-5-master")
        #expect(SenseiAssetProvider.imageName(for: .sensei) == "sensei-6-sensei")
    }

    @Test func everyRankHasADescription() {
        for rank in Rank.allCases {
            #expect(!SenseiAssetProvider.description(for: rank).isEmpty)
        }
    }

    @Test func realArtAssetsExistInBundle() {
        for rank in Rank.allCases {
            #expect(UIImage(named: SenseiAssetProvider.imageName(for: rank)) != nil)
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — `SenseiAssetProvider` not defined.

- [ ] **Step 3: Create `FUDO/Core/DesignSystem/SenseiAssetProvider.swift`**

```swift
import SwiftUI

/// Single indirection point mapping a Rank to its sensei artwork + a short state description.
/// Real art ships in Assets.xcassets (`sensei-1-novice`…`sensei-6-sensei`); a missing asset
/// falls back to an SF Symbol so no call site ever breaks when art is swapped.
enum SenseiAssetProvider {
    static func imageName(for rank: Rank) -> String {
        switch rank {
        case .novice:   return "sensei-1-novice"
        case .disciple: return "sensei-2-disciple"
        case .ascetic:  return "sensei-3-ascetic"
        case .warrior:  return "sensei-4-warrior"
        case .master:   return "sensei-5-master"
        case .sensei:   return "sensei-6-sensei"
        }
    }

    static func description(for rank: Rank) -> String {
        switch rank {
        case .novice:   return "Hooded, seated."
        case .disciple: return "Standing."
        case .ascetic:  return "Guard stance, faint aura."
        case .warrior:  return "Clear aura, staff in hand."
        case .master:   return "Wide aura."
        case .sensei:   return "Final iconic form."
        }
    }

    private static func fallbackSymbol(for rank: Rank) -> String {
        switch rank {
        case .novice:   return "figure.stand"
        case .disciple: return "figure.walk"
        case .ascetic:  return "figure.martial.arts"
        case .warrior:  return "figure.fencing"
        case .master:   return "flame"
        case .sensei:   return "crown"
        }
    }

    /// Real art if present, else an SF Symbol fallback.
    static func image(for rank: Rank) -> Image {
        UIImage(named: imageName(for: rank)) != nil
            ? Image(imageName(for: rank))
            : Image(systemName: fallbackSymbol(for: rank))
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run the Test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/DesignSystem/SenseiAssetProvider.swift FUDOTests/SenseiAssetProviderTests.swift
git commit -m "feat: SenseiAssetProvider (real art + fallback)"
```

---

### Task 8: Navigation toolkit (conventions encoded)

**Files:**
- Create: `FUDO/Core/Navigation/AppTab.swift`
- Create: `FUDO/Core/Navigation/TabBarVisibility.swift`
- Create: `FUDO/Core/Navigation/FudoTabBar.swift`
- Create: `FUDO/Core/Navigation/FudoNavigationStack.swift`
- Create: `FUDO/Core/Navigation/FudoSheet.swift`
- Create: `FUDO/Core/Navigation/FudoCover.swift`
- Create: `FUDO/Core/Navigation/FudoAlerts.swift`
- Test: `FUDOTests/NavigationTests.swift`

**Interfaces:**
- Consumes: `FudoColor`, `FudoSpacing`, `AppAnimation`, `Haptics`.
- Produces: `enum AppTab: Int, CaseIterable, Hashable` (`title`, `icon`); `@Observable final class TabBarVisibility { var isHidden }` + `.fudoHidesTabBar()`; `struct FudoTabBar` (`selected: Binding<AppTab>`); `struct FudoNavigationStack<Root: View>` (`path: Binding<NavigationPath>`, trailing `root`); `struct PushDemoDestination: Hashable { let title: String }`; `enum FudoSheet` + `.fudoSheet(item:content:)`; `enum FudoCover` + `.fudoCover(item:content:)`; `.fudoDestructiveConfirm(...)`, `.fudoSimpleAlert(...)`.

- [ ] **Step 1: Write the failing test** — `FUDOTests/NavigationTests.swift`:

```swift
import Testing
@testable import FUDO

struct NavigationTests {
    @Test func fourTabsInOrder() {
        #expect(AppTab.allCases == [.today, .progress, .stats, .settings])
    }

    @Test func tabTitles() {
        #expect(AppTab.today.title == "Today")
        #expect(AppTab.progress.title == "Progress")
        #expect(AppTab.stats.title == "Stats")
        #expect(AppTab.settings.title == "Settings")
    }

    @Test func sheetAndCoverAreIdentifiable() {
        #expect(FudoSheet.flame.id != FudoSheet.shareCard.id)
        #expect(FudoCover.onboarding.id != FudoCover.paywall.id)
    }

    @Test func visibilityDefaultsVisible() {
        #expect(TabBarVisibility().isHidden == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the Test command. Expected: FAIL — `AppTab` / `FudoSheet` / etc. not defined.

- [ ] **Step 3: Create `FUDO/Core/Navigation/AppTab.swift`**

```swift
import Foundation

/// The 4 tab destinations. Tab switch only — never a cross-tab push.
enum AppTab: Int, CaseIterable, Hashable {
    case today, progress, stats, settings

    var title: String {
        switch self {
        case .today: "Today"
        case .progress: "Progress"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: "house.fill"                     // DesignReference/app: house
        case .progress: "chart.bar.fill"              // bars
        case .stats: "chart.line.uptrend.xyaxis"      // trend line
        case .settings: "gearshape.fill"              // gear
        }
    }
}
```

- [ ] **Step 4: Create `FUDO/Core/Navigation/TabBarVisibility.swift`**

```swift
import SwiftUI
import Observation

/// Shared override so a screen can force-hide the floating pill regardless of
/// nav-path depth (belt-and-suspenders; primary hide is path-driven in MainTabView).
@Observable final class TabBarVisibility {
    var isHidden = false
}

private struct HidesTabBarModifier: ViewModifier {
    @Environment(TabBarVisibility.self) private var visibility
    func body(content: Content) -> some View {
        content
            .onAppear { visibility.isHidden = true }
            .onDisappear { visibility.isHidden = false }
    }
}

extension View {
    /// Force-hide the floating pill while this view is on screen.
    func fudoHidesTabBar() -> some View { modifier(HidesTabBarModifier()) }
}
```

- [ ] **Step 5: Create `FUDO/Core/Navigation/FudoTabBar.swift`**

```swift
import SwiftUI

/// Custom dark floating pill. Matches DesignReference/app 01/02/05/07:
/// every tab shows icon + label; active = vermillon icon+label inside a filled
/// highlight; inactive = grey (textSecondary), no fill. Pill = dark capsule + 1px border.
struct FudoTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self, content: tabButton)
        }
        .padding(6)
        .background(
            Capsule()
                .fill(FudoColor.bgCard)
                .overlay(Capsule().stroke(FudoColor.border, lineWidth: 1))
        )
        .animation(AppAnimation.standard, value: selected)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selected == tab
        return Button {
            Haptics.light()
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isActive ? FudoColor.accent : FudoColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(FudoColor.accent.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
```

- [ ] **Step 6: Create `FUDO/Core/Navigation/FudoNavigationStack.swift`**

```swift
import SwiftUI

/// Reusable PUSH container: native back, tab bar hidden (MainTabView hides the pill
/// when this stack's path is non-empty). Each root declares its own `.navigationDestination`.
struct FudoNavigationStack<Root: View>: View {
    @Binding var path: NavigationPath
    @ViewBuilder let root: () -> Root

    var body: some View {
        NavigationStack(path: $path) { root() }
    }
}

/// Foundations-only demo route used by placeholder screens to prove push hides the pill.
/// Real routes replace this in later sessions.
struct PushDemoDestination: Hashable { let title: String }
```

- [ ] **Step 7: Create `FUDO/Core/Navigation/FudoSheet.swift`**

```swift
import SwiftUI

/// SHEET destinations — detent .medium, grabber, swipe-down. Quick consult / picker.
enum FudoSheet: Identifiable {
    case flame, reminderTime, shareCard
    var id: Int {
        switch self {
        case .flame: 0
        case .reminderTime: 1
        case .shareCard: 2
        }
    }
}

extension View {
    func fudoSheet<Content: View>(
        item: Binding<FudoSheet?>,
        @ViewBuilder content: @escaping (FudoSheet) -> Content
    ) -> some View {
        sheet(item: item) { sheet in
            content(sheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(FudoColor.bgPrimary)
        }
    }
}
```

- [ ] **Step 8: Create `FUDO/Core/Navigation/FudoCover.swift`**

```swift
import SwiftUI

/// COVER destinations — full screen, NO gesture dismiss. Moments of flow.
enum FudoCover: Identifiable {
    case onboarding, paywall, challengeSetup, challengeComplete, rankUp
    var id: Int {
        switch self {
        case .onboarding: 0
        case .paywall: 1
        case .challengeSetup: 2
        case .challengeComplete: 3
        case .rankUp: 4
        }
    }
}

extension View {
    func fudoCover<Content: View>(
        item: Binding<FudoCover?>,
        @ViewBuilder content: @escaping (FudoCover) -> Content
    ) -> some View {
        fullScreenCover(item: item) { cover in
            content(cover).interactiveDismissDisabled(true)
        }
    }
}
```

- [ ] **Step 9: Create `FUDO/Core/Navigation/FudoAlerts.swift`**

```swift
import SwiftUI

/// Two-step destructive confirmation (abandon challenge, delete data): a first alert
/// then a second "are you sure" gate. Simple alert (uncheck) is a normal `.alert`.
private struct DestructiveConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void
    @State private var secondStep = false

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("Continue", role: .destructive) { secondStep = true }
                Button("Cancel", role: .cancel) {}
            } message: { Text(message) }
            .alert("Are you sure?", isPresented: $secondStep) {
                Button(confirmTitle, role: .destructive) { onConfirm() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This can't be undone.") }
    }
}

extension View {
    func fudoDestructiveConfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DestructiveConfirmModifier(
            isPresented: isPresented, title: title, message: message,
            confirmTitle: confirmTitle, onConfirm: onConfirm
        ))
    }

    func fudoSimpleAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button(confirmTitle, role: .destructive) { onConfirm() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(message) }
    }
}
```

- [ ] **Step 10: Run the test to verify it passes**

Run the Test command. Expected: PASS. Then run the Build command — Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 11: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/Navigation FUDOTests/NavigationTests.swift
git commit -m "feat: navigation toolkit (tabs, pill, sheet/cover/alert conventions)"
```

---

### Task 9: Placeholder views

**Files:**
- Create: `FUDO/Core/DesignSystem/PlaceholderScaffold.swift`
- Create: `FUDO/Features/Home/Views/HomePlaceholderView.swift`
- Create: `FUDO/Features/Progression/Views/ProgressionPlaceholderView.swift`
- Create: `FUDO/Features/Stats/Views/StatsPlaceholderView.swift`
- Create: `FUDO/Features/Settings/Views/SettingsPlaceholderView.swift`
- Create: `FUDO/Features/Onboarding/Views/OnboardingPlaceholderView.swift`
- Create: `FUDO/Features/Paywall/Views/PaywallPlaceholderView.swift`
- Create: `FUDO/Features/ChallengeSetup/Views/ChallengeSetupPlaceholderView.swift`
- Create: `FUDO/Features/Completion/Views/CompletionPlaceholderView.swift`
- Create: `FUDO/Features/Share/Views/SharePlaceholderView.swift`

**Interfaces:**
- Consumes: `FudoColor`, `FudoFont`, `FudoSpacing`, `PushDemoDestination` (Task 8).
- Produces: `PlaceholderScaffold`, `PushDemoScreen`, and 9 `*PlaceholderView` structs. The 4 tab placeholders declare `.navigationDestination(for: PushDemoDestination.self)` and a demo `NavigationLink`.

- [ ] **Step 1: Create `FUDO/Core/DesignSystem/PlaceholderScaffold.swift`**

```swift
import SwiftUI

/// Dark, token-styled placeholder. Foundations only — replaced by real screens later.
struct PlaceholderScaffold<Extra: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let extra: () -> Extra

    init(title: String, subtitle: String, @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.extra = extra
    }

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            VStack(spacing: FudoSpacing.cardPadding) {
                Text(title)
                    .font(FudoFont.title())
                    .foregroundStyle(FudoColor.textPrimary)
                Text(subtitle)
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.textSecondary)
                extra()
            }
            .padding(FudoSpacing.screenMargin)
        }
    }
}

/// Sub-screen pushed by the tab placeholders to prove the pill hides on push.
struct PushDemoScreen: View {
    let title: String
    var body: some View {
        PlaceholderScaffold(title: title, subtitle: "Pushed — pill hidden, native back restores it.")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Create the 4 tab placeholders** (each with the push-demo). `FUDO/Features/Home/Views/HomePlaceholderView.swift`:

```swift
import SwiftUI

struct HomePlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Today", subtitle: "Home — daily checklist lives here.") {
            NavigationLink(value: PushDemoDestination(title: "Today detail")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
```

`FUDO/Features/Progression/Views/ProgressionPlaceholderView.swift`:

```swift
import SwiftUI

struct ProgressionPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Progress", subtitle: "The challenge and the rank.") {
            NavigationLink(value: PushDemoDestination(title: "Progress detail")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
```

`FUDO/Features/Stats/Views/StatsPlaceholderView.swift`:

```swift
import SwiftUI

struct StatsPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Stats", subtitle: "The habits.") {
            NavigationLink(value: PushDemoDestination(title: "Habit detail")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
```

`FUDO/Features/Settings/Views/SettingsPlaceholderView.swift`:

```swift
import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Settings", subtitle: "Functional, not rich.") {
            NavigationLink(value: PushDemoDestination(title: "Settings subscreen")) {
                Text("Push demo →")
                    .font(FudoFont.body())
                    .foregroundStyle(FudoColor.accent)
            }
        }
        .navigationDestination(for: PushDemoDestination.self) { PushDemoScreen(title: $0.title) }
    }
}
```

- [ ] **Step 3: Create the 5 non-tab placeholders** (no push demo). `FUDO/Features/Onboarding/Views/OnboardingPlaceholderView.swift`:

```swift
import SwiftUI

struct OnboardingPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Onboarding", subtitle: "Cover flow — built in a later session.")
    }
}
```

`FUDO/Features/Paywall/Views/PaywallPlaceholderView.swift`:

```swift
import SwiftUI

struct PaywallPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Paywall", subtitle: "Cover flow — built in a later session.")
    }
}
```

`FUDO/Features/ChallengeSetup/Views/ChallengeSetupPlaceholderView.swift`:

```swift
import SwiftUI

struct ChallengeSetupPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Challenge Setup", subtitle: "Cover flow — built in a later session.")
    }
}
```

`FUDO/Features/Completion/Views/CompletionPlaceholderView.swift`:

```swift
import SwiftUI

struct CompletionPlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Completion", subtitle: "Challenge complete / abandon — built later.")
    }
}
```

`FUDO/Features/Share/Views/SharePlaceholderView.swift`:

```swift
import SwiftUI

struct SharePlaceholderView: View {
    var body: some View {
        PlaceholderScaffold(title: "Share Card", subtitle: "9:16 share card — built in a later session.")
    }
}
```

- [ ] **Step 4: Build to confirm everything compiles** (views unused so far, ContentView still root)

Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/Core/DesignSystem/PlaceholderScaffold.swift FUDO/Features
git commit -m "feat: placeholder views for all 9 features"
```

---

### Task 10: App shell — AppState, MainTabView, RootView, entry point

**Files:**
- Create: `FUDO/App/AppState.swift`
- Create: `FUDO/App/MainTabView.swift`
- Create: `FUDO/App/RootView.swift`
- Modify: `FUDO/FUDOApp.swift` (rewrite in place, then serve the move to `App/`)
- Served to Romain: `git mv FUDO/FUDOApp.swift FUDO/App/FUDOApp.swift`, `git rm FUDO/ContentView.swift`

**Interfaces:**
- Consumes: `AppTab`, `FudoNavigationStack`, `FudoTabBar`, `TabBarVisibility`, `.fudoCover`, `FudoColor`, `AppAnimation`, all placeholder views.
- Produces: `@Observable final class AppState` (`hasCompletedOnboarding`, `entitlementActive`, `hasActiveChallenge`, `selectedTab`); `struct MainTabView`; `struct RootView`; `FUDOApp` → `RootView`.

- [ ] **Step 1: Create `FUDO/App/AppState.swift`** — thin router, zero logic:

```swift
import SwiftUI
import Observation

/// Thin routing state ONLY. No game math, no persistence, no networking.
/// Real state plugs in behind these flags without AppState growing:
///  - GameStore (Session 1) assigns `hasActiveChallenge`.
///  - EntitlementStore (Session 6) assigns `entitlementActive`.
///  - Onboarding completion (later) assigns `hasCompletedOnboarding`.
@Observable final class AppState {
    var hasCompletedOnboarding = true   // SEAM (onboarding): default true until onboarding ships
    var entitlementActive = true        // SEAM (Session 6 EntitlementStore)
    var hasActiveChallenge = false      // SEAM (Session 1 GameStore)
    var selectedTab: AppTab = .today
}
```

- [ ] **Step 2: Create `FUDO/App/MainTabView.swift`** — stock TabView (bar hidden) + custom pill overlay, path-driven hide-on-push:

```swift
import SwiftUI

/// 4-tab shell. Per-tab NavigationPath preserves state per tab. The floating pill is an
/// overlay above the stock (hidden) tab bar; it hides whenever the selected tab has pushed.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var visibility = TabBarVisibility()
    @State private var paths: [AppTab: NavigationPath] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) }
    )

    private var pillHidden: Bool {
        let pushed = !(paths[appState.selectedTab]?.isEmpty ?? true)
        return pushed || visibility.isHidden
    }

    var body: some View {
        @Bindable var appState = appState
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                tab(.today) { HomePlaceholderView() }
                tab(.progress) { ProgressionPlaceholderView() }
                tab(.stats) { StatsPlaceholderView() }
                tab(.settings) { SettingsPlaceholderView() }
            }

            if !pillHidden {
                FudoTabBar(selected: $appState.selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(visibility)
        .animation(AppAnimation.standard, value: pillHidden)
    }

    @ViewBuilder
    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: @escaping () -> Root) -> some View {
        FudoNavigationStack(path: pathBinding(tab)) { root() }
            .toolbar(.hidden, for: .tabBar)   // hide stock bar; our pill replaces it
            .tag(tab)
    }

    private func pathBinding(_ tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { paths[tab] ?? NavigationPath() },
            set: { paths[tab] = $0 }
        )
    }
}
```

- [ ] **Step 3: Create `FUDO/App/RootView.swift`** — routing seam via cover:

```swift
import SwiftUI

/// Root routing: onboarding → paywall → tabs. Onboarding/paywall are covers (per conventions).
/// With current defaults (onboarding done, entitled) it lands on MainTabView.
struct RootView: View {
    @State private var appState = AppState()
    @State private var cover: FudoCover?

    var body: some View {
        MainTabView()
            .environment(appState)
            .preferredColorScheme(.dark)
            .fudoCover(item: $cover) { cover in
                switch cover {
                case .onboarding: OnboardingPlaceholderView()
                case .paywall: PaywallPlaceholderView()
                default: EmptyView()
                }
            }
            .onAppear(perform: evaluateRoute)
    }

    private func evaluateRoute() {
        if !appState.hasCompletedOnboarding {
            cover = .onboarding
        } else if !appState.entitlementActive {
            cover = .paywall
        } else {
            cover = nil
        }
    }
}
```

- [ ] **Step 4: Rewrite `FUDO/FUDOApp.swift` in place** (still at old path so the app keeps compiling):

```swift
import SwiftUI
import UIKit

@main
struct FUDOApp: App {
    init() {
        #if DEBUG
        assert(
            UIFont(name: "BebasNeue-Regular", size: 17) != nil,
            "Bebas Neue not registered — check UIAppFonts + Resources/Fonts/BebasNeue-Regular.ttf"
        )
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 5: Build with the old `ContentView.swift` still present**

Run the Build command. Expected: `** BUILD SUCCEEDED **` (ContentView is now unused but still compiles).

- [ ] **Step 6: SERVE the file move + delete to Romain** (do NOT run autonomously)

Tell Romain to run:
```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git mv FUDO/FUDOApp.swift FUDO/App/FUDOApp.swift
git rm FUDO/ContentView.swift
```

- [ ] **Step 7: After Romain runs it, build again**

Run the Build command. Expected: `** BUILD SUCCEEDED **` (synchronized groups pick up the new `App/FUDOApp.swift`; `ContentView` gone).

- [ ] **Step 8: Run all tests**

Run the Test command. Expected: PASS (all suites).

- [ ] **Step 9: Commit**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git add FUDO/App
git commit -m "feat: app shell — RootView, MainTabView (floating pill), thin AppState"
```

---

### Task 11: Final verification + protocol update

**Files:**
- Modify (brain repo): `../../../Guide/brain/project/STATE.md`, `../../../Guide/brain/project/DECISIONS.md`

(Brain absolute path: `/Users/romainsil/Documents/Loisirs/Code/Xcode/Guide/brain/project/`.)

**Interfaces:**
- Consumes: everything.
- Produces: verified build + simulator run; updated project state.

- [ ] **Step 1: Clean build**

Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Full test run**

Run the Test command. Expected: all suites PASS.

- [ ] **Step 3: Boot the app in the simulator and confirm the acceptance checks**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
xcodebuild -project FUDO.xcodeproj -scheme FUDO \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build install
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
xcrun simctl install booted "$(find build -name 'FUDO.app' -type d | head -1)"
xcrun simctl launch booted com.romain.FUDO
```
Confirm visually (Romain): dark forced; portrait locked; 4 tabs; floating pill with active tab as a filled vermillon capsule, inactive tabs icon-only; tapping "Push demo →" hides the pill and shows native back; back restores the pill; DEBUG font assertion did not trip.

- [ ] **Step 4: Confirm the repo is clean**

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/iOS/FUDO
git status --porcelain
```
Expected: empty (no untracked orphans). If `.DS_Store` appears, it's gitignored — ignore.

- [ ] **Step 5: Update brain `project/STATE.md`** — set status to "Foundations (Session 0) done; next: data layer (@Model entities + modelContainer, Session 1)".

- [ ] **Step 6: Append to brain `project/DECISIONS.md`**

```
| 2026-07-12 | Foundations: canonical STRUCTURE.md tree, minimal models (SharedTypes only), floating-pill TabView with path-driven hide-on-push, nav conventions as reusable modifiers, iOS 17 / portrait / iPhone-only | Every later session plugs into a fixed skeleton; GameConfig kept byte-identical to DATA-MODEL |
```

- [ ] **Step 7: Commit the protocol update** (brain repo, if it is a git repo; otherwise just save)

```bash
cd /Users/romainsil/Documents/Loisirs/Code/Xcode/Guide/brain
git add project/STATE.md project/DECISIONS.md 2>/dev/null && git commit -m "docs: FUDO foundations done" 2>/dev/null || true
```

---

## Self-Review

**Spec coverage (design spec §3 file manifest):**
- App/ (FUDOApp, RootView, MainTabView, AppState) → Task 10 ✓
- Core/Models/SharedTypes → Task 4 ✓
- Core/Game/GameConfig → Task 5 ✓
- Core/DesignSystem (Colors, Typography, Spacing, AppAnimation, Haptics, SenseiAssetProvider) → Tasks 2, 6, 3, 3, 3, 7 ✓
- Core/Extensions/Color+Hex → Task 2 ✓
- Core/Navigation (FudoTabBar, FudoNavigationStack, TabBarVisibility, FudoSheet, FudoCover, FudoAlerts, AppTab) → Task 8 ✓
- Features 9 placeholders → Task 9 ✓
- Nav conventions encoded (tab switch / sheet / push+hide / cover / two-step alert) → Tasks 8 + 10 ✓
- Bebas Neue verify + DEBUG assertion → Tasks 1, 6, 10 ✓
- AppState thin-router seams → Task 10 ✓
- Project settings (17.0 / portrait / iPhone / accent) → Task 1 ✓
- Served mv/rm → Task 10 ✓
- Verification (build + test + sim) → Task 11 ✓
- `Core/DesignSystem/Components/` intentionally empty (design spec §3) — no task, correct ✓

**Placeholder scan:** no "TBD"/"handle appropriately"; all code blocks complete.

**Type consistency:** `FudoColor`, `FudoFont`, `FudoSpacing`, `AppAnimation`, `Haptics`, `Rank`, `GameConfig`, `AppTab`, `FudoTabBar`, `FudoNavigationStack(path:root:)`, `PushDemoDestination`, `FudoSheet`, `FudoCover`, `TabBarVisibility`, `AppState`, `MainTabView`, `RootView`, `PlaceholderScaffold`, `PushDemoScreen`, the 9 `*PlaceholderView` — names identical across producing and consuming tasks. `SenseiAssetProvider.imageName/description/image` consistent. ✓

**Note:** resolved for this machine — sim `iPhone 17` (available), bundle id `com.romain.FUDO`. If the sim list changes, pick any available iPhone from `xcrun simctl list devices available`.
