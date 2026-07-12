# Design — Data layer + game engine (Session 1)

> Statut : approuvé par Romain le 2026-07-12 (4 questions + design global).
> Source de vérité des règles : `docs/DATA-MODEL.md` (ce doc ne la duplique pas — il fixe la surface API,
> le découpage fichiers et les 4 décisions de session).

## Périmètre

IN : 4 `@Model` SwiftData, `OnboardingAnswers`, `OVREngine`, `GameStore`, `DebugSeed`, tests Swift Testing,
câblage container + environment + rollover on scene-active. AUCUN écran.
OUT (sessions futures) : WidgetBridge/snapshot (pas de target widget), notifications, onboarding UI,
RevenueCat/PostHog, écrans de fin/rank-up (le store expose les triggers, l'UI viendra les consommer).

## Décisions de session (actées 2026-07-12)

1. **Gap days** : rollover crée + clôture un DayLog synthétique pour CHAQUE jour manquant, en ordre
   chronologique — pool figé sur l'OVR courant du moment, pénalité par jour, 1 point `ovrHistory` par jour.
   App tuée 3 jours = 3 chutes visibles.
2. **`startingOVR`** : input = struct `OnboardingAnswers` typée, 4 enums (scroll é2, procrastination é4,
   struggle é7, commitment é13), chaque case porte ses points (barème DATA-MODEL §3a). Clamp [40, 50].
3. **DebugSeed** : replay moteur — pas de valeurs statiques. Base 49 (answers typées : scroll <2h +4,
   procrastination "stopped lying" +2, struggle "start strong then quit" +2, commitment Very +1).
   J1–J6 complets · J7 raté (chute visible, streak cassée) · J8–J11 complets (streak 4) · J12 = today,
   3/5 checkés → OVR affiché 61 (Ascetic). Asserts DEBUG : displayedOVR == 61, streak == 4, day 12.
4. **Câblage** : `ModelContainer` créé dans `FUDOApp.init` (do/catch explicite ; échec de création au boot =
   `fatalError` documenté, seul cas toléré), GameStore en environment, `scenePhase == .active` →
   `processRolloverIfNeeded()`, `AppState.hasActiveChallenge` alimenté par le store, DebugSeed au premier
   lancement DEBUG si base vide.

## Fichiers

| Fichier | Rôle |
|---|---|
| `FUDO/Core/Models/Challenge.swift` | `@Model`, champs verbatim DATA-MODEL §1 + computed (`endDate`, `currentDayNumber(now:)`, `isRuleEditingLocked(now:)`) |
| `FUDO/Core/Models/TaskRule.swift` | `@Model`, incl. `domain: String?` (v1.1, nil), `isActive`, `sortOrder` |
| `FUDO/Core/Models/DayLog.swift` | `@Model`, `checks: [TaskCheck]`, `dailyGainPool` figé à la création, `isComplete`/`isClosed`/`ovrDelta` figés à la clôture |
| `FUDO/Core/Models/PlayerState.swift` | `@Model` singleton (fetch-or-create), persiste ENTRE les défis, `highestRankReached` (D6), `lastDayClosedAt`, `lastDecayTickAt` |
| `FUDO/Core/Game/OnboardingAnswers.swift` | struct + 4 enums, points par case (§3a) |
| `FUDO/Core/Game/OVREngine.swift` | enum stateless — toute constante vient de `GameConfig`, zéro nombre magique |
| `FUDO/Core/Services/GameStore.swift` | `@Observable`, SEUL point de mutation UI↔moteur, `nowProvider: () -> Date` + `calendar` injectables |
| `FUDO/Core/Services/DebugSeed.swift` | `#if DEBUG` intégral |
| `FUDOTests/OVREngineTests.swift` | moteur pur |
| `FUDOTests/GameStoreTests.swift` | container in-memory, horloge simulée |

Relations : `Challenge.rules` / `Challenge.dayLogs` en `.cascade` avec inverses (`TaskRule.challenge`,
`DayLog.challenge`). Unicité (challenge, date) des DayLog + invariant « 1 seul `.active` » enforcés par
GameStore (pas de contrainte composite iOS 17).

## Surface OVREngine (pur, stateless)

```swift
enum OVREngine {
    static func startingOVR(from answers: OnboardingAnswers) -> Double          // clamp 40...50
    static func dailyGainPool(currentOVR: Double) -> Double                     // (99 − ovr) × dailyRate ; = dayCompletionDelta
    static func checkDelta(pool: Double, alreadyGained: Double,
                           uncheckedActiveCount: Int) -> Double                 // remaining / count — cap structurel
    static func refund(for check: TaskCheck) -> Double                          // −check.ovrDelta, exact
    static func missedDayPenalty(pool: Double) -> Double                        // max(penaltyMin, pool × penaltyFactor)
    static func daysToClose(now: Date, lastProcessedDay: Date?,
                            calendar: Calendar) -> [Date]                       // jour effectif = startOfDay(now − graceHours)
    static func closeDay(isComplete: Bool, pool: Double, checksTotal: Double,
                         currentOVR: Double, currentStreak: Int,
                         bestStreak: Int) -> DayClosure                         // (newOVR, newStreak, newBest, ovrDelta)
    static func decayTicksDue(daysIdle: Int, ticksAlreadyApplied: Int) -> Int
    static func decayedOVR(current: Double, ticks: Int) -> Double               // plancher Rank.floorOVR à CHAQUE tick
    static func rank(forOVR: Double) -> Rank                                    // délègue Rank.from
    static func project(from base: Double, days: Int) -> Double                 // 99 − (99−base) × (1−dailyRate)^days — é10 l'appellera
}
```

Sémantique grace period : jour effectif = `startOfDay(now − 2 h)`. Un check à 1 h 59 tombe sur le log
d'hier (toujours le jour effectif) ; à 2 h 01 le rollover a clôturé hier d'abord. Clôture silencieuse,
jamais rétroactive.

Anti-farming : le pool du jour est figé ; chaque check consomme `remaining / nbNonCochées` ; re-check après
uncheck re-consomme le pool restauré (neutre au total) ; somme des deltas ≤ pool structurellement.

## GameStore

```swift
@Observable final class GameStore {
    init(modelContext: ModelContext, calendar: Calendar = .current, nowProvider: @escaping () -> Date = Date.init)

    private(set) var pendingRankUp: Rank?      // D6 — consommé par la COVER plus tard, 1× par rang

    func checkTask(_ rule: TaskRule)           // delta live + TaskCheck horodaté + rank-up check
    func uncheckTask(_ rule: TaskRule)         // reprise EXACTE du delta
    func processRolloverIfNeeded()             // §3e : clôtures (+ synthétiques) → complétion défi → log du jour → decay → seam AppState
    func startChallenge(preset:durationDays:rules:reminderMinutes:) 
    func abandonChallenge()                    // pénalité standard jour courant, streak 0, endOVR figé (confirmation ×2 côté UI plus tard)
}
```

- `PlayerState` : fetch-or-create, jamais 2 instances, jamais reset entre défis.
- Rank-up (D6) : à CHAQUE hausse d'OVR, si `rank.rawValue > highestRankReached` → `pendingRankUp` PUIS
  remonter le mark. Le store est le seul écrivain du mark.
- Complétion : au rollover du dernier jour → `.completed`, `endOVR` figé, `completedChallengesCount += 1`.
- Toute erreur SwiftData gérée (zéro `try!`, zéro force unwrap).
- Decay appliqué en catch-up dans `processRolloverIfNeeded` quand aucun défi actif (`lastDecayTickAt`).

## Tests (Swift Testing)

Moteur : gain dégressif près de 99 · refund exact (check/uncheck neutre) · cap jamais dépassé (somme
deltas == pool à 100 %) · pénalité + streak cassée sur jour incomplet · grace 1 h 59 vs 2 h 01 ·
multi-jours manqués en ordre (pénalités séquentielles) · plancher decay au bas du rang · bornes de rang
49/50 et 89/90 · `startingOVR` bornes [40, 50] · `project(43, 30) ≈ 78`.
Store (in-memory) : check/uncheck neutre en base · rollover crée les logs synthétiques · complétion
incrémente le compteur · 1 seul `.active` · seed valide (61 / streak 4 / J12 / 3 checks).

Vérif par étape : compile-only `xcodebuild build -destination 'generic/platform=iOS Simulator'`.
Suite complète (sim booté) : UNE fois, fin de session.
