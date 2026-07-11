# DATA-MODEL — SwiftData définitif (MVP)

4 entités `@Model` + 2 structs `Codable` embarquées + 2 enums. 100 % local, target app uniquement. Le widget ne touche JAMAIS SwiftData : il lit un `WidgetSnapshot` JSON (Codable) écrit dans UserDefaults App Group (`group.<bundleID>`) par l'app à chaque check/uncheck/rollover (modèle P7 de PROMPTS-BUILD). Montage : `.modelContainer(for: [Challenge.self, TaskRule.self, DayLog.self, PlayerState.self])`.

Convention dates : toute date "jour" est normalisée `Calendar.current.startOfDay(for:)`. OVR stocké en `Double` (précision de la formule dégressive), affiché en `Int` via `floor` (on ne montre jamais un point non acquis).

---

## 1. Entités

### Challenge

| Propriété | Type Swift | Contraintes / notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `preset` | `ChallengePreset` (enum String) | `.monk30` / `.monk60` / `.hardcore90` / `.classic75` / `.custom` |
| `durationDays` | `Int` | 30 / 60 / 75 / 90 (modifiable au setup) |
| `startDate` | `Date` | startOfDay du jour 1 |
| `status` | `ChallengeStatus` (enum String) | `.active` / `.completed` / `.abandoned` — **invariant : 1 seul `.active` à la fois** (enforcer en code, pas de contrainte composite SwiftData sur iOS 17) |
| `reminderMinutes` | `Int` | heure du rappel quotidien en minutes depuis minuit (ex. 7h00 = 420) |
| `restDayWeekday` | `Int?` | **D5 — jour de repos, structure only, AUCUNE UI au MVP.** `nil` par défaut ; index `Calendar` (1 = dimanche … 7 = samedi). Row Settings virée du MVP (prd/12 §6), le champ existe pour la feature v1.1 sans migration |
| `startOVR` | `Double` | OVR au lancement (pour le récap 43 → 76) |
| `endOVR` | `Double?` | figé à la clôture (completed/abandoned), `nil` sinon |
| `rulesLockedAfterDay` | `Int` | = `GameConfig.rulesLockDay` (3) — copié à la création pour audit |
| `createdAt` | `Date` | |
| `rules` | `[TaskRule]` | `@Relationship(deleteRule: .cascade, inverse: \TaskRule.challenge)` |
| `dayLogs` | `[DayLog]` | `@Relationship(deleteRule: .cascade, inverse: \DayLog.challenge)` |

Computed (pas persistés) : `endDate` (= startDate + durationDays − 1), `currentDayNumber(now:)`, `isRuleEditingLocked(now:)` (jour courant > 3).

### TaskRule

| Propriété | Type Swift | Contraintes / notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `title` | `String` | éditable au setup (≤ J3) |
| `iconName` | `String` | SF Symbol |
| `domain` | `String?` | **v1.1 (radar)** — présent en base dès le MVP, aucune UI. `nil` par défaut |
| `isActive` | `Bool` | toggle du preset au setup ; une règle désactivée ne compte pas dans le jour |
| `sortOrder` | `Int` | ordre d'affichage checklist |
| `createdAt` | `Date` | |
| `challenge` | `Challenge?` | inverse de `Challenge.rules` |

Récurrence : quotidienne implicite (pas de champ au MVP). Max `GameConfig.maxRules` (8) règles actives par défi.

### DayLog

Un log par jour de défi. Créé au rollover (ou au premier accès du jour). Unicité (challenge, date) enforced par `RolloverService` (pas de `#Unique` composite en iOS 17).

| Propriété | Type Swift | Contraintes / notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `date` | `Date` | startOfDay |
| `dayNumber` | `Int` | 1-based (jour X / Y) |
| `checks` | `[TaskCheck]` | struct Codable embarquée (voir §2) — tâches cochées avec heure + delta exact |
| `dailyGainPool` | `Double` | **plafond OVR du jour**, figé à la création du log : `(99 − ovrAtDayStart) × GameConfig.dailyRate` |
| `isComplete` | `Bool` | 100 % des règles actives cochées (figé à la clôture) |
| `isClosed` | `Bool` | rollover passé (après grace period) |
| `ovrDelta` | `Double` | net appliqué ce jour = somme des deltas de checks − pénalité éventuelle (figé à la clôture) |
| `challenge` | `Challenge?` | inverse de `Challenge.dayLogs` |

### PlayerState (singleton — fetch-or-create, jamais 2 instances)

Créé en fin d'onboarding avec l'OVR de départ. **Persiste entre les défis** (le rang est l'identité, le défi est un moyen).

| Propriété | Type Swift | Contraintes / notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `ovrValue` | `Double` | 0.0 … 99.0. Affichage : `Int(ovrValue.rounded(.down))` |
| `currentStreak` | `Int` | journées 100 % consécutives (MAJ à chaque clôture) |
| `bestStreak` | `Int` | record all-time |
| `ovrHistory` | `[OVRPoint]` | struct Codable — 1 point par clôture de jour + par tick de decay (alimente la courbe Progression) |
| `completedChallengesCount` | `Int` | défis terminés (status `.completed`) |
| `highestRankReached` | `Int` | **D6 — high-water mark du rang (`Rank.rawValue`).** Ne descend JAMAIS. Alimente (1) le CHEMIN Progression : un rang ≤ highestRankReached s'affiche en COULEUR même si l'OVR redescend, au-dessus = silhouette noire ; (2) le trigger COVER rank-up : célébration 1× par rang, uniquement quand `Rank.from(ovr:) > highestRankReached` → on remonte le mark, la re-montée après un decay ne re-célèbre pas |
| `lastDayClosedAt` | `Date?` | dernier rollover traité (idempotence) |
| `lastDecayTickAt` | `Date?` | dernier tick de decay appliqué |
| `createdAt` | `Date` | |

Computed : `rank: Rank` (dérivé de `ovrValue`, jamais stocké), `displayedOVR: Int`, `highestRank: Rank` (= `Rank(rawValue: highestRankReached)`). **Invariant rank-up : à chaque MAJ de l'OVR, si `rank.rawValue > highestRankReached` → déclencher la COVER rank-up (D6) PUIS `highestRankReached = rank.rawValue`.** Le GameStore est le seul point qui remonte le mark.

### Agrégations UX v2 (aucun champ nouveau — dérivées des `DayLog.checks`)

Les écrans Stats (prd/10), Habit detail (prd/12 §5) et le Sheet flamme (prd/12 §2) n'ajoutent **aucune** donnée : ils agrègent l'existant. À vérifier au build que le modèle les rend calculables :
- **`TaskCheck.checkedAt` est bien horodaté** → timeline habit detail « Day 12 · ✓ checked 7:42 AM » et heure exacte par check. ✅ déjà dans le struct §2.
- **Streak PAR habitude** : dérivable en balayant les `DayLog` du défi triés par date, une habitude « tenue » un jour = un `TaskCheck` avec son `ruleID` dans `DayLog.checks`. Pas de champ dédié.
- **7 pastilles semaine (sheet flamme)** : `DayLog.isComplete` + `DayLog.date` sur les 7 derniers jours (fait / raté / today = ring partiel du jour en cours / à venir = vide).
- **Total checks all-time (sheet flamme)** : `Σ DayLog.checks.count` sur tous les défis. **Best streak = `bestStreak`** déjà présent.
- **Tendance / top-flop / % complétion (Stats)** : agrégation par `ruleID` sur la fenêtre choisie (7 / 30 / défi), règles §Données de prd/10.

---

## 2. Types embarqués (Codable, stockés par SwiftData dans les @Model)

```swift
struct TaskCheck: Codable, Equatable {
    let ruleID: UUID        // référence TaskRule.id
    let checkedAt: Date     // heure exacte du hold-to-check
    let ovrDelta: Double    // delta EXACT accordé à ce check → reprise exacte au décochage
}

struct OVRPoint: Codable, Equatable {
    let date: Date          // startOfDay
    let value: Double       // ovrValue après application du delta du jour
}

enum ChallengePreset: String, Codable { case monk30, monk60, hardcore90, classic75, custom }
enum ChallengeStatus: String, Codable { case active, completed, abandoned }

enum Rank: Int, CaseIterable {          // dérivé de l'OVR, jamais persisté
    case novice, disciple, ascetic, warrior, master, sensei
    // Novice 0-49 · Disciple 50-59 · Ascetic 60-69 · Warrior 70-79 · Master 80-89 · Sensei 90-99
    var floorOVR: Double { [0, 50, 60, 70, 80, 90][rawValue] }   // plancher decay
    static func from(ovr: Double) { /* switch sur les paliers */ }
}
```

Hors SwiftData (UserDefaults App Group) : `hasCompletedOnboarding: Bool`, `onboardingAnswers` (pour le calcul base OVR, jetables après), flags de notifs demandées. Jamais de donnée de jeu dans UserDefaults.

---

## 3. Formule OVR (source de vérité unique : `Core/Game/OVREngine.swift`)

Toutes les constantes dans `GameConfig` :

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

### 3a. OVR de départ (base 40-50, calculé depuis l'onboarding)

```
base = 40
+ scroll (é2)        : <2h:+4 · 2-4h:+3 · 4-6h:+1 · 6h+:+0
+ procrastination(é4): "j'ai arrêté de me mentir":+2 · chaque mois:+1 · chaque semaine:+0
+ struggle (é7)      : "je commence fort et j'abandonne":+2 · "3 jours max":+1 · "même pas commencer":+0
+ commitment (é13)   : Extremely:+2 · Very:+1 · Un peu:+0
→ résultat ∈ [40, 50]   (ex. type PRD : 43)
```

### 3b. Gain journalier dégressif vers 99 + plafond + anti-farming

Le jour est doté d'un **pool figé au rollover** ; chaque check consomme une part du pool ; journée 100 % = pool entier. Structurellement : plafond journalier respecté, rien ne paie 2×.

```
// au rollover (création du DayLog du jour) :
dailyGainPool = (99 − ovrValue) × dailyRate            // dégressif : plus t'es haut, moins tu gagnes

// au hold-to-check d'une règle :
remaining   = dailyGainPool − Σ(checks.ovrDelta)
delta       = remaining / nbRèglesActivesNonCochées     // répartition robuste si les règles bougent (≤ J3)
checks.append(TaskCheck(ruleID, now, delta))
ovrValue    = min(99, ovrValue + delta)                 // appliqué EN LIVE (le Home et le sensei réagissent)

// au décochage (tap long + confirmation) :
ovrValue   -= check.ovrDelta                            // reprise EXACTE — neutre au centime
checks.removeAll { $0.ruleID == ruleID }
```

Convergence géométrique : après n journées parfaites depuis base b, `ovr = 99 − (99 − b) × (1 − dailyRate)^n`. Calibration (b = 43, aucune journée ratée) :

| Défi parfait | OVR final | Rang atteint |
|---|---|---|
| 30 j | ~78 | Warrior (= la projection "43 → 78" de l'onboarding é10) |
| 60 j | ~91 | Sensei (run parfait de 60 j = rarissime, assumé) |
| 90 j | ~96 | Sensei haut (Hardcore élite) |

→ Sensei (90+) exige structurellement plusieurs défis ou un run long quasi parfait (acté PRD 07). **L'écran de projection d'onboarding (é10) DOIT appeler `OVREngine.project(from:days:)` — jamais une courbe dessinée à la main.**

### 3c. Pénalité jour raté (au rollover, jamais rétroactif)

```
// clôture d'un jour (à 2 h du matin, ou au premier lancement après) :
if jour 100 % coché :
    isComplete = true ; currentStreak += 1 ; bestStreak = max(...)
else :
    penalty  = max(penaltyMin, dailyGainPool × penaltyFactor)   // ex. OVR 43 → pool 1.85 → -3.7 ≈ "-4" affiché
    ovrValue = max(0, ovrValue − penalty)                       // PAS de plancher de rang : perdre un rang par échec est possible (c'est la menace)
    currentStreak = 0
    // les gains partiels des tâches cochées restent acquis (déjà appliqués en live)
ovrDelta du DayLog = Σ(checks.ovrDelta) − penaltyÉventuelle ; isClosed = true
ovrHistory.append(OVRPoint(date, ovrValue))
// bandeau factuel le lendemain : "Yesterday: incomplete. OVR -4."
```

Abandon de défi (Réglages, confirmé 2×) : appliquer une pénalité standard (calculée sur le jour courant), `currentStreak = 0`, `status = .abandoned`, `endOVR` figé. Historique conservé.

### 3d. Decay d'inactivité (anti-churn naturel, plancher de rang)

Uniquement quand **aucun défi actif**. Calculé en catch-up au lancement / refresh widget (pas de démon) :

```
idleStart = date de fin/abandon du dernier défi
if daysSince(idleStart) >= decayStartDays :                     // notif "Ton OVR rouille" à J7, AVANT le 1er tick
    ticksDus  = (daysSince(idleStart) − decayStartDays) / decayIntervalDays  // -1 tous les 3 j
    ticksFaits = déjà appliqués via lastDecayTickAt
    for _ in (ticksFaits..<ticksDus) :
        ovrValue = max(rank.floorOVR, ovrValue − decayAmount)   // PLANCHER = bas du rang courant :
        ovrHistory.append(...)                                  // on ne perd JAMAIS un rang par decay,
    lastDecayTickAt = now                                       // on glisse vers sa limite basse
```

### 3e. Rollover — ordonnancement (RolloverService, idempotent)

Au lancement / retour foreground / refresh widget :
1. Clôturer tous les `DayLog` non fermés dont `date < startOfDay(now − graceHours)` (checks entre minuit et 2 h comptent pour la veille — silencieux).
2. Si dernier jour du défi clôturé → `status = .completed`, `endOVR` figé, `completedChallengesCount += 1` → écran fin de défi.
3. Sinon créer le `DayLog` du jour (fige `dailyGainPool`).
4. Sans défi actif → appliquer le decay (3d).
5. Recalculer la timeline widget + replanifier les notifs conditionnelles (rappel supprimé si journée déjà 100 %).

---

## 4. Points d'équilibrage (constantes à tuner au build, JAMAIS sans accord Romain)

- `dailyRate` 0.033 : monte → progression plus rapide mais Sensei trop accessible ; descend → "glorified checklist" (review LOCKED).
- `penaltyFactor` / `penaltyMin` : trop punitif = churn (leçon Her 75) ; l'échec doit piquer, pas tuer.
- Affichage du delta par check ("+0.4 OVR" flottant) : choix UI à trancher au build — valeur exacte vs delta du jour cumulé. La donnée exacte est là (`TaskCheck.ovrDelta`).
- Decay 7 j / -1 par 3 j : à confronter aux data PostHog post-launch.
