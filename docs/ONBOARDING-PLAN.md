# FUDO — Onboarding (Session 5) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire le tunnel d'onboarding complet — 25 écrans (OB 00 → OB 21 + un gate paywall), en 5 actes, de l'ambiance vidéo au widget promo, en réutilisant le moteur et le design system existants sans en dupliquer une ligne.

**Architecture:** Une machine à états (`OnboardingStep`, enum `CaseIterable`) pilotée par un `OnboardingViewModel` `@Observable` unique ; un `OnboardingFlowView` (cover plein écran, aucun `NavigationStack`) qui `switch` sur l'étape courante et applique une transition directionnelle. Les réponses vivent dans un `OnboardingDraft` mutable, converti en `OnboardingAnswers` (type existant, non modifié) pour appeler `OVREngine`. Zéro calcul OVR local : `startingOVR`, `project`, `Rank.from`, `displayedOVR` viennent tous du moteur. La composition du défi (OB 11) réutilise `ChallengeSetupViewModel` tel quel. La persistance se fait en 2 checkpoints (`PlayerState` à la signature, `Challenge` au loader post-paywall) + des flags UserDefaults qui verrouillent le routage.

**Tech Stack:** Swift / SwiftUI, iOS 17+, `@Observable`, SwiftData (via `GameStore` uniquement), AVFoundation (`AVPlayerLayer` pour les vidéos welcome), Swift Charts (courbe de projection), `UNUserNotificationCenter` (rappel quotidien réel), `@Environment(\.requestReview)` (prompt Apple natif), swift-testing (`import Testing`).

---

## ⚠️ AMENDEMENT 2026-07-16 — restructuration du flow (actée, LIVRÉE)

> Cet amendement SUPERSÈDE l'ordre des étapes décrit dans le corps du plan
> ci-dessous (pattern RiteOff : le loader analyse AVANT le reveal). Le code et
> `OnboardingStepTests` sont la vérité ; le corps du plan reste la référence
> pour le contenu de chaque écran.

**Nouvel ordre** (`OnboardingStep`) :
`splash → transformation → pain → mechanism` (acte 0, inchangé) →
`painPoint → scrollHours → age → procrastination → shockStat → goals → struggle → reflection` (quiz) →
**`loaderAnalysis`** (ex-`loaderBuilding`, déplacé : loader narratif "ANALYZING YOUR ANSWERS", stats orbitales `analysisLoaderStats` — SANS OVR ni durée —, sortie = pilule "Access your report") →
**`report`** (NOUVEL écran `ReportScreen` : le SEUL écran dense du funnel — synthèse fight / screen time + shock / weak spot / targets / potential via `OnboardingCopy.reportRows`, l'OVR délibérément absent) →
`diagnostic` (le reveal : count-up 0,8 s, rouge éteint `accentMuted`, tampon rang) →
`compose` → `projection` (reste APRÈS compose — la date exacte a besoin de la durée choisie ; son loader d'avant a disparu, remplacé par un beat "Locking your protocol…" de 0,9 s dans `ProjectionScreen`) →
`firstCheck → socialProof → commitment → contract → paywall → notifications → loaderSetup → welcomeDojo → widgetPromo` (inchangé).

**Invariants tenus** : D1 intact (diagnostic/projection = plancher, bonus à OB 16) · enum exhaustive, ordre verrouillé par `theLoaderAnalyzesBeforeTheReportRevealAndProjectionFollowsCompose` · barre de progression : quiz + report + reveal (16 steps), masquée sur `loaderAnalysis` · `OnboardingLoaderScreen` ne sert plus qu'à OB 19 (auto-advance + création du défi).

---

## Global Constraints

Ces contraintes s'appliquent à CHAQUE tâche, implicitement. Valeurs copiées verbatim de `CLAUDE.md` / du brief.

- **iOS 17+**, Swift / SwiftUI, `@Observable` (jamais `ObservableObject`). Un fichier = une view.
- **Organisation** : tout le neuf sous `FUDO/Features/Onboarding/` (VM + types à la racine, views dans `Views/`). Le transverse (notifications) sous `FUDO/Core/Services/`.
- **Dark only** : `.preferredColorScheme(.dark)` est déjà posé par `RootView` — ne jamais le re-déclarer, ne jamais coder de logique light/dark.
- **Couleurs** : uniquement les tokens de `FudoColor`. Jamais de hex dans une view. Vert (`positive`) autorisé UNIQUEMENT sur la ligne "RECOMMENDED FOR YOU" (exception actée 2026-07-12). `celebrationGold` réservé aux célébrations (OB 14 flamme day-0, étoiles OB 15).
- **Spacing** : `FudoSpacing.screenMargin` 20 · `cardPadding` 16 (20 majeur) · `sectionGap` 40 · `radiusCard` 24 · `radiusNested` 8 · `ctaHeight` 56 (Capsule) · `ringWidth` 6.
- **Typo** : `.fudoFont(_:)` TOUJOURS, jamais `.font(.system(size:))`. App UI = SF Pro. **Bebas Neue = `.fudoFont(.onboardingDisplay(_:))`, hooks display de l'onboarding UNIQUEMENT** (OB 00-01c). `UIAppFonts` est déjà déclaré dans `FUDO/Info.plist` avec `BebasNeue-Regular.ttf` — rien à ajouter.
- **Animations** : `AppAnimation.standard` (0.5 s ease-in-out) / `AppAnimation.slow` (0.6 s). Jamais de durée en dur dans une view : toute nouvelle constante va dans `OnboardingMetrics`.
- **Haptics** : transitions d'écran (`Haptics.light()`), révélations de beat (`Haptics.medium()`), hold-to-check (géré par `HoldToConfirm`). Nulle part ailleurs.
- **Gameplay** : `GameConfig` et la formule OVR sont INTOUCHABLES. `OVREngine` est la source unique. Aucun nombre magique de gameplay dans une view.
- **Copy** : EN only, 2e personne, direct, dur-mais-satisfait. Une idée / max une question / un seul CTA par écran.
- **Pas de force unwrap** (`!`), pas de `try!`. Aucun `Date.now` dans une view : horloge = `store.effectiveToday` / `store.displayCalendar`.
- **Tests SwiftData** : toute suite qui touche un `@Model` DOIT passer par `SwiftDataTestSupport.freshContainer()` et être `@Suite(.serialized)`. Ne JAMAIS instancier un `@Model` sans container.
- **Builds** : vérif par étape = compile-only sans simulateur (`xcodebuild build -destination 'generic/platform=iOS Simulator'`). UN SEUL `xcodebuild test` par session, à la toute fin. Jamais deux `xcodebuild` en parallèle.

---

## Décisions — TRANCHÉES par Romain (2026-07-15)

| # | Sujet | Décision | Conséquence dans le plan |
|---|---|---|---|
| **D1** | **L'engagement (OB 16) arrive APRÈS l'OVR diagnostic (OB 10) et la projection (OB 13)** — or `DATA-MODEL §3a` fait entrer `commitment` (+0/+1/+2) dans l'OVR de départ. Le nombre d'OB 10 ne peut donc pas être final. | ✅ **Bonus révélé.** OB 10/13 calculent avec `commitment = .somewhat` (0 pt) = le PLANCHER. OB 16 réveille le bonus, OB 17 affiche la valeur finale. **Le nombre ne fait que MONTER.** | `OnboardingDraft.answers` défaute `commitment` à `.somewhat` · OB 16 affiche un "+N OVR" flottant · verrouillé par `theDiagnosticShowsTheFloorAndTheCommitmentRaisesIt`. Zéro modif de la formule. |
| **D2** | **"Your Monk Mode starts tomorrow" (OB 19/20) contredit "Day 1 = aujourd'hui"** (décision 2026-07-12). Piège dérivé : onboarder à 21 h = pénalité garantie la nuit 1. | ✅ **Recouper la copy.** Moteur intact. | OB 19 footer → `Day 1 starts today. Almost there.` · OB 20 corps → `Day 1 is today. Your reminder rings tomorrow at [time].` · **piège "onboarding du soir" logué** pour une session ultérieure (option `startDay:` + état Home "Day 0"). |
| **D3** | **Preset recommandé** (OB 11) dérivé des réponses. | ✅ **Toujours `.monk30`** (reco appliquée). | `OnboardingCopy.recommendedPreset(for:)` retourne `.monk30` · verrouillé par `theRecommendedPresetIsAlwaysTheThirtyDayStake` · les chips laissent 60/75/90 accessibles. |
| **D4** | **Preuve sociale fabriquée** : note "4.8", "2× more likely to finish", "statistically dead by day 4". Aucune n'est mesurée. | ✅ **Non-chiffré tout de suite.** Aucune mesure inventée n'entre dans le build. | Copy honnête livrée dès la Task 15/19/20 (cf. `SocialProofCopy` ci-dessous). **Rien à corriger avant submit.** ⚠️ **Reste ouvert : les 3 témoignages nominatifs** — cf. la note sous ce tableau. |
| **D5** | **Ping-pong vidéo (01a / 01c, start ≠ end)**. Le décodage H.264 arrière est non fiable sur device. | ✅ **Dissolve-loop.** | `WelcomeStageView` : deux `AVPlayerLayer`, fondu `OnboardingMetrics.videoCrossfade` sur la couture ET entre les clips. Aucun `rate = -1`. |
| **D6** | **Barre de progression sur OB 18** : la frame la montre pleine, la règle dit cachée. | ✅ **Cachée** (reco appliquée). | `OnboardingStep.notifications.showsProgress == false`, verrouillé par test. |
| **D7** | **Prix en dur** ($5.99/wk, $43.99/yr) sur OB 17. | ✅ **Stub S5 → RevenueCat en S6** (reco appliquée). | `PricingCopy` isolé, remplacé par les `StoreProduct` localisés en S6 (Apple exige le prix réel + le renouvellement auto à l'écran). |

### ⚠️ Le point resté ouvert : les témoignages d'OB 15

D4 a réglé les **chiffres** inventés. Les 3 témoignages nominatifs (`"Held 60 days for the first time in my life." — Ryan, 19 — OVR 71`, etc.) sont de la même famille : ce sont des **attributions inventées à des personnes nommées**. Non mesurable ≠ non attribuable, mais le problème est le même — un témoignage fabriqué présenté comme réel est trompeur, et nominatif il est juridiquement plus exposé qu'une note.

**Il n'y a que deux sorties honnêtes, et aucune ne bloque le build de S5 :**
- **A (reco)** — les collecter en TestFlight avant soumission. Les strings restent dans `SocialProofCopy`, marquées en dur `// PLACEHOLDER — real, consented tester quotes required before submit`. L'écran se construit et se valide en sim tel quel ; c'est une **action pré-submit**, pas une tâche de code.
- **B** — virer les témoignages : OB 15 devient l'écran du prompt de review natif seul (titre + étoiles décoratives supprimées + CTA). Plus court, 100 % propre tout de suite, mais l'écran perd sa raison d'être ("You are not alone").

**À trancher avant soumission, pas avant l'Acte 2.** Le plan construit l'option A (structure complète, placeholders marqués).

### `SocialProofCopy` — les strings honnêtes livrées (D4)

```swift
/// The proof strings. D4 (Romain, 2026-07-15): NO invented measurement ships —
/// no App Store rating we haven't earned, no "2× more likely" nobody measured,
/// no "statistically" in front of a number that doesn't exist. What's left says
/// the same thing without claiming a study.
enum SocialProofCopy {
    // OB 15 — no rating line, no stars: both ARE a rating claim.
    static let proofTitle = "Men like you,\nlocked in."

    // PLACEHOLDER — real, consented tester quotes required before submit (see plan §D4 open point).
    static let testimonials: [(quote: String, author: String)] = [
        ("Held 60 days for the first time in my life.", "— Ryan, 19 — OVR 71"),
        ("Started at 41. OVR 91 today. Different person.", "— Marcus, 22 — Sensei"),
        ("The character evolving is what kept me going.", "— Tom, 24 — OVR 84"),
    ]

    // OB 18 — was "you are statistically dead by day 4".
    static let reminderStake = "Without it, most men are done by day 4."

    // OB 21 — was "Users with the widget are 2× more likely to finish."
    static let widgetStake = "The widget is the difference between remembering and finishing."
}
```

### Divergences frames vs code (loguées, tranchées ici — pas de décision requise)

1. **OB 13 / OB 17 : "~78 · MASTER"** → 78 est **Warrior** (70-79), Master ouvre à 80. Bug de maquette. Le rang se dérive de `Rank.from(ovr:)`, jamais d'une string.
2. **OB 11 : "CLASSIC · RECOMMENDED FOR YOU"** avec la chip 30 d sélectionnée → incohérent. Le nom vient de `PresetCatalog.title(for:days:)` (source unique) → "MONK MODE 30 · RECOMMENDED FOR YOU".
3. **Icônes emoji** (OB 01c, OB 11, OB 18, flamme) → **SF Symbols** (convention actée 2026-07-13 sur Stats). Flamme = `flame.fill` + `FudoGradient.flame`.
4. **OB 14 : "Hold for 1.5 seconds"** → `HoldToConfirmMetrics.duration` vaut **1.0** depuis le polish device. La copy ne porte plus de nombre : **"Hold to check."**
5. **OB 18 : "reminder at 6:30 AM"** / **OB 20 : "6:30 AM"** → la valeur vient de `ChallengeSetupViewModel.reminderMinutes` (défaut 420 = 7:00 AM).
6. **OB 21 : widget "DAY 12 / 30", OVR 47, 🔥11** → maquette. Le mock affiche des valeurs FIXES de démo (c'est une illustration du widget, pas l'état du joueur) — assumé, mais aligné sur le vrai design du widget (session ultérieure).
7. **OB 15 : "4.8 on the App Store"** → voir D4.

---

## Carte des fichiers

### Créés — `FUDO/Features/Onboarding/`

| Fichier | Responsabilité |
|---|---|
| `OnboardingStep.swift` | L'enum des 25 étapes + `showsProgress` / `showsBack` / **`progressTotal` calculé** (jamais numéroté à la main). |
| `OnboardingDraft.swift` | Les réponses en cours (optionnelles) + `Pain`, `AgeBracket`, `Goal` + conversion vers `OnboardingAnswers`. |
| `ShockMath.swift` | Le calcul "X years scrolled away" (OB 06). Pur, testable. |
| `OnboardingCopy.swift` | Le moteur de recoupe : shock line, reflection, enemy line, preset recommandé, dates. Pur, testable. |
| `OnboardingMetrics.swift` | Toutes les constantes UI de l'onboarding (durées loaders, hold signature, crossfade vidéo, tailles de hooks). |
| `OnboardingFlags.swift` | UserDefaults : kill-safety, hold-lock, `ContractSnapshot` Codable. |
| `OnboardingViewModel.swift` | La machine à états : step courant, direction, draft, spam guard, checkpoints, `ChallengeSetupViewModel` possédé. |
| `Views/OnboardingFlowView.swift` | Le `switch` sur l'étape + transitions + fond. |
| `Views/OnboardingScaffold.swift` | Le squelette commun quiz/valeur : progress + back + eyebrow + titre + contenu + CTA. |
| `Views/OnboardingProgressBar.swift` | La barre (fraction calculée). |
| `Views/OptionRow.swift` | La row d'option (single + multi select). |
| `Views/WelcomeStageView.swift` | Deux `AVPlayerLayer` + crossfade + dissolve-loop + fallback image. |
| `Views/SplashScreen.swift` | OB 00. |
| `Views/WelcomeHookScreen.swift` | OB 01a / 01b / 01c (data-driven par un descriptor). |
| `Views/ProtocolGlassCard.swift` | La carte glass inclinée de OB 01c. |
| `Views/SingleChoiceScreen.swift` | OB 02 / 03 / 04 / 05 / 08 / 16 (data-driven). |
| `Views/MultiChoiceScreen.swift` | OB 07. |
| `Views/ShockStatScreen.swift` | OB 06. |
| `Views/ReflectionScreen.swift` | OB 09. |
| `Views/DiagnosticScreen.swift` | OB 10. |
| `Views/ComposeProtocolScreen.swift` | OB 11 (skin onboarding de `ChallengeSetupViewModel`). |
| `Views/OnboardingLoaderScreen.swift` | OB 12 + OB 19 (même composant). |
| `Views/ProjectionScreen.swift` + `Views/ProjectionCurveView.swift` | OB 13. |
| `Views/FirstCheckScreen.swift` | OB 14. |
| `Views/SocialProofScreen.swift` | OB 15. |
| `Views/ContractScreen.swift` + `Views/SignatureCanvas.swift` | OB 17. |
| `Views/NotificationsScreen.swift` | OB 18. |
| `Views/WelcomeDojoScreen.swift` | OB 20. |
| `Views/WidgetPromoScreen.swift` | OB 21. |

### Créés — ailleurs

| Fichier | Responsabilité |
|---|---|
| `FUDO/Core/Services/NotificationService.swift` | Autorisation + planification RÉELLE du rappel quotidien. |
| `FUDO/Features/Paywall/Views/PaywallGateView.swift` | Stub S5 du paywall, remplacé en S6. |
| `FUDOTests/OnboardingStepTests.swift` | Total de progression calculé, maps back/progress. |
| `FUDOTests/ShockMathTests.swift` | Les 16 combinaisons + bascule années/jours. |
| `FUDOTests/OnboardingCopyTests.swift` | Recoupes, jointure des goals, preset reco. |
| `FUDOTests/OnboardingViewModelTests.swift` | Spam guard, avance/retour, draft → answers, checkpoints. |
| `FUDOTests/OnboardingFlagsTests.swift` | Kill-safety : reprise après kill. |

### Modifiés

| Fichier | Modif |
|---|---|
| `FUDO/Core/DesignSystem/HoldToConfirm.swift` | Ajout d'un paramètre `ringWidth` (défaut = `HoldToConfirmMetrics.ringWidth`) — le gros anneau HOLD d'OB 14 a besoin d'un trait épais. Même pattern que l'ajout de `ringColor` (2026-07-13) : tous les call sites gardent le défaut. |
| `FUDO/App/RootView.swift` | Routage + hold-lock post-paywall + montage de `OnboardingFlowView`. |
| `FUDO/App/AppState.swift` | `hasCompletedOnboarding` alimenté par `OnboardingFlags` (le seam se branche). |
| `FUDO/Core/Services/GameStore.swift` | Extension DEBUG : `debugReplayOnboarding()`. |
| `FUDO/Core/Services/DebugSeed.swift` | Le seed marque l'onboarding comme fait (le joueur seedé EST onboardé). |
| `FUDO/Features/Settings/Views/DebugMenuSection.swift` | Action "Replay onboarding". |

---

## Machine à états et barre de progression

**La règle du brief : le total de la barre est CALCULÉ, jamais écrit à la main.** L'enum est la source ; ajouter/retirer un écran recalcule tout automatiquement.

```swift
/// The 25 onboarding screens, in order. The progress bar's total is DERIVED from
/// this enum (never hand-numbered): add a step and every fraction re-computes.
enum OnboardingStep: Int, CaseIterable {
    // Act 0 — welcome (no progress bar)
    case splash, transformation, pain, mechanism
    // Act 1 — diagnostic & self-persuasion
    case painPoint, scrollHours, age, procrastination, shockStat, goals, struggle, reflection, diagnostic
    // Act 2 — climax
    case compose, loaderBuilding, projection, firstCheck, socialProof
    // Act 3 — engagement & contract
    case commitment, contract, paywall
    // Act 4 — post-paywall
    case notifications, loaderSetup, welcomeDojo, widgetPromo

    /// Hidden on the welcome act, both loaders, the paywall and the whole
    /// post-paywall trio (brief + decision D6).
    var showsProgress: Bool {
        switch self {
        case .splash, .transformation, .pain, .mechanism,
             .loaderBuilding, .loaderSetup, .paywall,
             .notifications, .loaderSetup, .welcomeDojo, .widgetPromo:
            return false
        default:
            return true
        }
    }

    /// Back is offered on the questions only. The walls (reflection, first check,
    /// social proof, commitment, contract), the loaders and the post-paywall trio
    /// have no way back — matching the frames.
    var showsBack: Bool {
        switch self {
        case .painPoint, .scrollHours, .age, .procrastination, .shockStat,
             .goals, .struggle, .diagnostic, .compose, .projection:
            return true
        default:
            return false
        }
    }

    /// The screens that carry the bar, in order — the ONE list the bar counts.
    static var progressSteps: [OnboardingStep] { allCases.filter(\.showsProgress) }

    static var progressTotal: Int { progressSteps.count }

    /// 1-based position among the progress-carrying steps; nil when the bar is hidden.
    var progressIndex: Int? {
        Self.progressSteps.firstIndex(of: self).map { $0 + 1 }
    }

    /// 0…1 fill of the bar. Full on the contract — the last bar-carrying screen.
    var progressFraction: Double? {
        progressIndex.map { Double($0) / Double(Self.progressTotal) }
    }
}
```

> ⚠️ Le `switch showsProgress` ci-dessus liste `loaderSetup` deux fois — c'est une coquille du plan à ne PAS recopier : la Task 2 écrit la version corrigée (chaque case une seule fois). Le test `OnboardingStepTests` la verrouille de toute façon (Swift refuse un case dupliqué à la compilation).

Contrôle : les 15 écrans porteurs = OB 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 13, 14, 15, 16, 17. → OB 02 = 1/15 (6,7 %, sliver de la frame ✓), OB 16 = 14/15 (93 %, quasi plein ✓), OB 17 = 15/15 (plein ✓).

---

## Kill-safety, checkpoints et hold-lock

Le brief demande "insert User(hasCompletedOnboarding=false) at the signed contract". FUDO n'a pas de modèle `User` : l'équivalent est **`PlayerState`** (singleton, `GameStore.ensurePlayer`) + un flag UserDefaults (`DATA-MODEL` : `hasCompletedOnboarding` vit en UserDefaults, jamais en SwiftData).

| Checkpoint | Quand | Ce qui est écrit | Si l'app est tuée juste après |
|---|---|---|---|
| **0** | Avant OB 17 | Rien de persistant (le draft vit en mémoire) | L'onboarding recommence à OB 00. ~60 s perdues, assumé. |
| **1 — Le contrat signé** | Fin du hold "HOLD TO SIGN" (OB 17) | `GameStore.ensurePlayer(startingOVR:)` **+** `OnboardingFlags.contract = ContractSnapshot(...)` (le protocole composé, sérialisé) | Le joueur existe, l'OVR est réel. La reprise repart au **paywall** avec le protocole intact. |
| **2 — Le paywall passé** | Sortie de `PaywallGateView` | `OnboardingFlags.hasCompletedOnboarding = true` | La reprise repart au **post-paywall** (OB 18). Le quiz ne rejoue JAMAIS. |
| **3 — Le trio fini** | Fin d'OB 21 | `OnboardingFlags.hasFinishedPostPaywall = true` + `contract = nil` | L'app s'ouvre sur Home day 1. |

**Le hold-lock** : entre le checkpoint 2 et le 3, `hasCompletedOnboarding` est vrai MAIS `hasFinishedPostPaywall` est faux → `RootView` maintient la cover `.onboarding`, le flow reprend à `.notifications`. Aucune route vers l'app tant que le trio n'est pas fini.

**Pourquoi le `Challenge` n'est PAS créé à la signature :** s'il l'était, l'horloge du jour 1 tournerait pendant que l'user est bloqué au paywall → un jour raté qu'il ne pouvait pas cocher → pénalité fantôme. Il est créé au **loader OB 19, étape "Saving your protocol"** — c'est littéralement ce que dit l'écran. L'invariant "trial expiré sans achat → paywall, données conservées" tient : le `PlayerState` et son OVR existent dès la signature.

**Piège DEBUG :** `DebugSeed.seedIfNeeded` crée un joueur au lancement. `ensurePlayer` étant un fetch-or-create, l'onboarding rejoué sur une base seedée récupèrerait l'OVR 61 au lieu de 43. D'où (Task 22) : le seed marque l'onboarding fait, et le rejeu passe par `debugReplayOnboarding()` qui vide TOUT **sans recréer de joueur**.

---

## Note d'exécution sur les views

Ce plan donne le **code complet** pour la logique (enums, moteurs de copy, VM, flags, service de notifs, composants partagés) et leurs tests. Pour les 25 écrans, il donne la **spec exacte** (copy verbatim, tokens, cotes, animations, transition, état écrit) et non 2 500 lignes de SwiftUI : l'implémenteur écrit la view contre la frame correspondante de `DesignReference/onboarding/`, qu'il DOIT ouvrir avant d'écrire l'écran. Chaque écran est vérifié par Romain dans le simulateur en fin d'acte — c'est le gate réel.

---

# ACTE 0 — Welcome (OB 00 → OB 01c)

**Livrable :** l'app s'ouvre sur le splash vidéo, on traverse les 3 hooks en fondu, on arrive sur un écran stub "Act 1". Vérifiable dans le sim.

---

### Task 1 : Squelette de l'onboarding (étapes, metrics, flags, VM minimal)

**Files:**
- Create: `FUDO/Features/Onboarding/OnboardingStep.swift`
- Create: `FUDO/Features/Onboarding/OnboardingMetrics.swift`
- Create: `FUDO/Features/Onboarding/OnboardingFlags.swift`
- Test: `FUDOTests/OnboardingStepTests.swift`
- Test: `FUDOTests/OnboardingFlagsTests.swift`

**Interfaces:**
- Produces: `OnboardingStep` (+ `showsProgress`, `showsBack`, `progressTotal`, `progressIndex`, `progressFraction`, `next`, `previous`) ; `OnboardingMetrics` ; `OnboardingFlags` (+ `ContractSnapshot`, `resumeStep`).

- [ ] **Step 1 : Écrire le test qui échoue — le total de la barre est calculé**

```swift
import Testing
@testable import FUDO

struct OnboardingStepTests {

    @Test func progressTotalIsDerivedFromTheEnum() {
        // The bar's total is never hand-numbered: it IS the count of bar-carrying steps.
        #expect(OnboardingStep.progressTotal == OnboardingStep.allCases.filter(\.showsProgress).count)
        #expect(OnboardingStep.progressTotal == 15)
    }

    @Test func welcomeLoadersAndPostPaywallHideTheBar() {
        let hidden: [OnboardingStep] = [.splash, .transformation, .pain, .mechanism,
                                        .loaderBuilding, .loaderSetup, .paywall,
                                        .notifications, .welcomeDojo, .widgetPromo]
        for step in hidden {
            #expect(step.showsProgress == false, "\(step) must hide the progress bar")
            #expect(step.progressFraction == nil)
        }
    }

    @Test func theContractFillsTheBar() {
        #expect(OnboardingStep.contract.progressIndex == OnboardingStep.progressTotal)
        #expect(OnboardingStep.contract.progressFraction == 1.0)
    }

    @Test func theFirstQuestionOpensTheBar() {
        #expect(OnboardingStep.painPoint.progressIndex == 1)
    }

    @Test func barCarryingStepsAreOrderedAndContiguous() {
        // Guards against a step being filtered out of order after a re-shuffle.
        let indices = OnboardingStep.progressSteps.map(\.rawValue)
        #expect(indices == indices.sorted())
    }

    @Test func backIsOfferedOnQuestionsAndBlockedOnWalls() {
        for step in [OnboardingStep.painPoint, .scrollHours, .age, .procrastination,
                     .shockStat, .goals, .struggle, .diagnostic, .compose, .projection] {
            #expect(step.showsBack, "\(step) must offer back")
        }
        for step in [OnboardingStep.splash, .reflection, .loaderBuilding, .firstCheck,
                     .socialProof, .commitment, .contract, .paywall,
                     .notifications, .loaderSetup, .welcomeDojo, .widgetPromo] {
            #expect(step.showsBack == false, "\(step) must block back")
        }
    }

    @Test func nextWalksTheWholeFunnelAndStops() {
        #expect(OnboardingStep.splash.next == .transformation)
        #expect(OnboardingStep.contract.next == .paywall)
        #expect(OnboardingStep.widgetPromo.next == nil)
        #expect(OnboardingStep.splash.previous == nil)
        #expect(OnboardingStep.scrollHours.previous == .painPoint)
    }
}
```

- [ ] **Step 2 : Lancer le test — il doit échouer**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: FAIL — "cannot find 'OnboardingStep' in scope".

- [ ] **Step 3 : Écrire `OnboardingStep.swift`**

Le code de la section "Machine à états" ci-dessus, **avec le `switch showsProgress` corrigé** (chaque case une seule fois : `.splash, .transformation, .pain, .mechanism, .loaderBuilding, .loaderSetup, .paywall, .notifications, .welcomeDojo, .widgetPromo`), plus la navigation :

```swift
extension OnboardingStep {
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}
```

- [ ] **Step 4 : Écrire `OnboardingMetrics.swift`**

```swift
import Foundation
import CoreGraphics

/// Every onboarding-only constant — no magic numbers in the screens (CLAUDE.md).
/// Motion stays inside the 0.4-0.6 s house curve (AppAnimation); the values here
/// are BEATS (how long a moment lasts), not curves.
enum OnboardingMetrics {
    /// Cross-fade between two welcome clips (01a → 01b → 01c) and on the loop seam.
    static let videoCrossfade: TimeInterval = 0.5
    /// Splash hint "Tap anywhere" — slow breath, never a blink.
    static let hintPulse: TimeInterval = 1.8
    /// Ensō scale-in on the splash.
    static let ensoScaleFrom: CGFloat = 0.96

    /// OB 12 "Building your protocol…" — 4 narrative steps.
    static let buildLoaderDuration: TimeInterval = 4.4
    /// OB 19 "Setting up your protocol…" — the brief's ~7 s beat.
    static let setupLoaderDuration: TimeInterval = 7.0

    /// OB 06 count-up of the shock number — sober, no bounce.
    static let countUpDuration: TimeInterval = 1.2
    /// OB 10 / OB 13 reveal beat before the number lands.
    static let revealDelay: TimeInterval = 0.35

    /// OB 17 "HOLD TO SIGN" — heavier than a checklist hold: this one binds.
    static let signHoldDuration: TimeInterval = 2.5
    /// OB 14's HOLD ring: a 148 pt circle needs a thicker stroke than a card's 3 pt.
    static let firstCheckRingDiameter: CGFloat = 148
    static let firstCheckRingWidth: CGFloat = 7
    /// How long the day-0 flame lingers before OB 14 auto-advances.
    static let firstCheckSettle: TimeInterval = 1.4

    /// Ignore a second CTA tap fired inside one transition (RiteOff ctaSpamGuard).
    static let ctaGuard: TimeInterval = 0.5

    /// Bebas hook sizes (brief, verbatim).
    enum Hook {
        static let transformationLead: CGFloat = 34
        static let transformationClimax: CGFloat = 62
        static let painLead: CGFloat = 42
        static let painClimax: CGFloat = 56
        static let mechanismLead: CGFloat = 46
        static let mechanismClimax: CGFloat = 72
        /// A 62 pt Bebas line at AX sizes would overflow the phone: let it shrink
        /// rather than truncate. The hook IS the screen — it never wraps to 3 lines.
        static let minimumScale: CGFloat = 0.75
    }
}
```

- [ ] **Step 5 : Écrire le test qui échoue — kill-safety des flags**

```swift
import Foundation
import Testing
@testable import FUDO

@Suite(.serialized)
struct OnboardingFlagsTests {

    /// Each test owns its own suite name so the real app defaults are never touched.
    private func freshFlags(_ name: String = UUID().uuidString) -> OnboardingFlags {
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return OnboardingFlags(defaults: defaults)
    }

    @Test func aFreshInstallStartsTheFunnelAtTheSplash() {
        let flags = freshFlags()
        #expect(flags.hasCompletedOnboarding == false)
        #expect(flags.hasFinishedPostPaywall == false)
        #expect(flags.isFullyDone == false)
        #expect(flags.resumeStep == .splash)
    }

    @Test func aKillAfterTheSignatureResumesAtThePaywallWithTheProtocolIntact() {
        let flags = freshFlags()
        let snapshot = ContractSnapshot(startingOVR: 43, projectedOVR: 78.6,
                                        preset: .monk30, durationDays: 30,
                                        reminderMinutes: 420,
                                        rules: [.init(title: "Cold shower", iconName: "drop.fill")])
        flags.contract = snapshot

        #expect(flags.resumeStep == .paywall)
        #expect(flags.contract?.durationDays == 30)
        #expect(flags.contract?.rules.first?.title == "Cold shower")
        #expect(flags.isFullyDone == false)
    }

    @Test func aKillAfterThePaywallResumesAtTheNotificationsAndNeverReplaysTheQuiz() {
        let flags = freshFlags()
        flags.contract = ContractSnapshot(startingOVR: 43, projectedOVR: 78.6,
                                          preset: .monk30, durationDays: 30,
                                          reminderMinutes: 420, rules: [])
        flags.hasCompletedOnboarding = true

        #expect(flags.resumeStep == .notifications)
        #expect(flags.isFullyDone == false, "the hold-lock still blocks the app")
    }

    @Test func theHoldLockOnlyOpensWhenTheTrioIsFinished() {
        let flags = freshFlags()
        flags.hasCompletedOnboarding = true
        #expect(flags.isFullyDone == false)
        flags.hasFinishedPostPaywall = true
        #expect(flags.isFullyDone)
    }

    @Test func finishingClearsTheContractDraft() {
        let flags = freshFlags()
        flags.contract = ContractSnapshot(startingOVR: 43, projectedOVR: 78.6,
                                          preset: .monk30, durationDays: 30,
                                          reminderMinutes: 420, rules: [])
        flags.markFullyCompleted()
        #expect(flags.isFullyDone)
        #expect(flags.contract == nil, "the draft is disposable once the challenge exists")
    }

    @Test func resetReplaysTheWholeFunnel() {
        let flags = freshFlags()
        flags.markFullyCompleted()
        flags.reset()
        #expect(flags.resumeStep == .splash)
        #expect(flags.isFullyDone == false)
    }
}
```

- [ ] **Step 6 : Lancer — échec attendu**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: FAIL — "cannot find 'OnboardingFlags' in scope".

- [ ] **Step 7 : Écrire `OnboardingFlags.swift`**

```swift
import Foundation

/// The composed protocol, frozen at the signature (kill-safety checkpoint 1).
/// Disposable: it exists only between the signature and the challenge's creation
/// at the OB 19 loader. Codable so a kill mid-paywall loses nothing.
struct ContractSnapshot: Codable, Equatable {
    struct Rule: Codable, Equatable {
        var title: String
        var iconName: String
    }

    var startingOVR: Double
    var projectedOVR: Double
    var preset: ChallengePreset
    var durationDays: Int
    var reminderMinutes: Int
    var rules: [Rule]
}

/// Onboarding persistence — flags + the disposable contract draft. NEVER game data
/// (DATA-MODEL: gameplay lives in SwiftData, this lives in UserDefaults).
///
/// `defaults` is injected so tests own a throwaway suite, and so the App Group
/// swap (when the widget target lands) is a ONE-line change here.
final class OnboardingFlags {
    private enum Key {
        static let completed = "onboarding.hasCompleted"
        static let postPaywall = "onboarding.hasFinishedPostPaywall"
        static let contract = "onboarding.contract"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Flipped at the paywall (checkpoint 2): the quiz never replays after this.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.completed) }
        set { defaults.set(newValue, forKey: Key.completed) }
    }

    /// Flipped at the end of OB 21 (checkpoint 3). The HOLD-LOCK: until it is true,
    /// routing keeps the onboarding cover up even though onboarding "completed".
    var hasFinishedPostPaywall: Bool {
        get { defaults.bool(forKey: Key.postPaywall) }
        set { defaults.set(newValue, forKey: Key.postPaywall) }
    }

    var contract: ContractSnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.contract) else { return nil }
            return try? JSONDecoder().decode(ContractSnapshot.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Key.contract)
                return
            }
            defaults.set(data, forKey: Key.contract)
        }
    }

    /// The ONE gate RootView reads. Both checkpoints must be past.
    var isFullyDone: Bool { hasCompletedOnboarding && hasFinishedPostPaywall }

    /// Where a relaunch re-enters the funnel.
    var resumeStep: OnboardingStep {
        if hasCompletedOnboarding { return .notifications }   // paywall passed → the trio
        if contract != nil { return .paywall }               // signed → straight to the paywall
        return .splash                                        // nothing committed → replay
    }

    /// Checkpoint 3: the trio is done, the challenge exists, the draft is dead weight.
    func markFullyCompleted() {
        hasCompletedOnboarding = true
        hasFinishedPostPaywall = true
        contract = nil
    }

    func reset() {
        defaults.removeObject(forKey: Key.completed)
        defaults.removeObject(forKey: Key.postPaywall)
        defaults.removeObject(forKey: Key.contract)
    }
}
```

- [ ] **Step 8 : Lancer les tests — ils doivent passer**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED (l'exécution des tests = le run unique de fin de session).

- [ ] **Step 9 : Commit**

```bash
git add FUDO/Features/Onboarding FUDOTests/OnboardingStepTests.swift FUDOTests/OnboardingFlagsTests.swift
git commit -m "feat(onboarding): step machine, metrics and kill-safety flags"
```

---

### Task 2 : La scène vidéo welcome (`WelcomeStageView`)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/WelcomeStageView.swift`

**Interfaces:**
- Consumes: `OnboardingMetrics.videoCrossfade` (Task 1).
- Produces: `WelcomeClip` (enum : `.dojo`, `.phone`, `.doors` → nom de fichier vidéo + nom d'image de secours + `loopMode`), `WelcomeStageView(clip: WelcomeClip)`.

**Spec :**
- Deux `AVPlayerLayer` (A/B) dans un `UIViewRepresentable`, `videoGravity = .resizeAspectFill`, `isMuted = true`, `actionAtItemEnd = .none`.
- **Changement de clip** (01a→01b→01c) : la couche inactive charge le nouveau clip, joue, et les deux opacités se croisent sur `OnboardingMetrics.videoCrossfade` (0,5 s) → mouvement continu, jamais de noir.
- **Boucle** (D5, `dissolveLoop`) : pour `.dojo` et `.doors` (start ≠ end), à `duration − videoCrossfade`, la couche inactive redémarre le MÊME clip à 0 et les opacités se croisent → la couture devient un fondu. Pour `.phone` (directionnel bleu→vermillon), `loopMode = .forward` : `AVPlayerLooper` + micro-fondu identique sur la couture.
- **Fallback** (obligatoire, construit maintenant) : si l'asset vidéo est introuvable, si `AVPlayerItem.status == .failed`, ou si `ProcessInfo.processInfo.isLowPowerModeEnabled` → une `Image` chargée depuis `Bundle.main.url(forResource:withExtension:"jpg")` (`anchor-01a-dojo` / `anchor-01b-phone` / `anchor-01c-doors`), `.resizable().scaledToFill()`, même crossfade entre écrans.
- **Cadrage** : `GeometryReader` + `.frame(...)` + `.clipped()` — jamais de padding au hasard (piège connu "médias qui débordent").
- **Cycle de vie** : `pause()` sur `scenePhase != .active`, `play()` au retour. Un seul `WelcomeStageView` vivant pour tout l'Acte 0 (il est dans `OnboardingFlowView`, pas dans chaque écran) — les hooks se crossfadent PAR-DESSUS lui.
- **Scrim** : le gradient existe déjà par-dessus (Task 3) ; la vidéo passe DESSOUS, jamais l'inverse.

- [ ] **Step 1 : Vérifier que les assets sont bien bundlés (assert DEBUG, même pattern que Bebas)**

Dans `WelcomeStageView`, en `#if DEBUG` au chargement d'un clip :

```swift
#if DEBUG
assert(Bundle.main.url(forResource: clip.videoName, withExtension: "mp4") != nil
       || Bundle.main.url(forResource: clip.stillName, withExtension: "jpg") != nil,
       "Welcome media missing from the bundle — check FUDO/Resources/Welcome/ is in the synchronized group")
#endif
```

- [ ] **Step 2 : Écrire `WelcomeStageView.swift`**

Structure attendue :

```swift
import AVFoundation
import SwiftUI

/// The three welcome ambiences. Each carries its clip, its still fallback and how
/// it loops: 01a/01c start ≠ end (dissolve the seam), 01b is directional
/// (blue → vermillon) and only ever plays forward.
enum WelcomeClip: Equatable {
    case dojo, phone, doors

    var videoName: String {
        switch self {
        case .dojo: "welcome-01a"
        case .phone: "welcome-01b"
        case .doors: "welcome-01c"
        }
    }

    var stillName: String {
        switch self {
        case .dojo: "anchor-01a-dojo"
        case .phone: "anchor-01b-phone"
        case .doors: "anchor-01c-doors"
        }
    }

    /// D5: no reverse playback (H.264 backwards decoding stutters on device).
    /// The seam is dissolved instead — the eye reads continuous motion.
    var dissolvesSeam: Bool { self != .phone }
}
```

+ le `UIViewRepresentable` à deux couches et le fallback SwiftUI. Documenter en tête du fichier la décision D5 et la raison (le prochain lecteur doit savoir pourquoi ce n'est pas un vrai ping-pong).

- [ ] **Step 3 : Compile-only**

Run: `xcodebuild build -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4 : Commit**

```bash
git add FUDO/Features/Onboarding/Views/WelcomeStageView.swift
git commit -m "feat(onboarding): welcome video stage with dissolve loop and still fallback"
```

---

### Task 3 : OB 00 → OB 01c — les 4 écrans de l'Acte 0

**Files:**
- Create: `FUDO/Features/Onboarding/Views/SplashScreen.swift`
- Create: `FUDO/Features/Onboarding/Views/WelcomeHookScreen.swift`
- Create: `FUDO/Features/Onboarding/Views/ProtocolGlassCard.swift`
- Create: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`
- Modify: `FUDO/App/RootView.swift`

**Interfaces:**
- Consumes: `WelcomeStageView`, `WelcomeClip` (Task 2) ; `OnboardingStep`, `OnboardingMetrics`, `OnboardingFlags` (Task 1).
- Produces: `OnboardingFlowView(store: GameStore, onFinished: () -> Void)`.

#### Le scrim (partagé par les 4 écrans)

Deux couches, TOUJOURS entre la vidéo et le texte :
1. `LinearGradient(colors: [FudoColor.bgPrimary.opacity(0.35), FudoColor.bgPrimary.opacity(0.92)], startPoint: .top, endPoint: .bottom)` — le texte tient sur n'importe quelle frame.
2. **Vignette de focus radiale** : `RadialGradient(colors: [.clear, FudoColor.bgPrimary.opacity(0.75)], center: .center, startRadius: 120, endRadius: 420)` — demandée sur 01a/01b/01c.
   Sur OB 00, la vignette est **renforcée** (`startRadius: 60`, opacité 0.85) : le splash est un point focal, pas un décor.

---

#### OB 00 — SPLASH

- **Purpose :** Le premier souffle. Pas une app, un dojo. L'user comprend en 2 s que c'est sobre, dur, japonais — et qu'il n'y a rien à décider : il touche, ça commence.
- **Copy (verbatim) :**
  - Wordmark : `FUDO`
  - Hint : `Tap anywhere`
- **UI / layout :**
  - Fond : `WelcomeStageView(clip: .dojo)` plein bleed + scrim radial renforcé.
  - Centre : `Image("enso-100")` (Asset Catalog, existant) `.resizable().scaledToFit().frame(width: 200)`, teinté `FudoColor.accent` s'il n'est pas déjà vermillon.
  - Wordmark PAR-DESSUS l'ensō, centré : `.fudoFont(.title(34, weight: .bold))`, `.kerning(8)`, `FudoColor.textPrimary`. (SF Pro et non Bebas : les lettrages de la frame sont ceux de SF Pro Display — le wordmark est un logo, pas un hook.)
  - Hint bas d'écran, `.fudoFont(.caption(15))`, `FudoColor.textPrimary.opacity(0.45)`, `padding(.bottom, 40)`.
  - **AUCUN bouton.** Toute la surface est tappable : `.contentShape(Rectangle()).onTapGesture { vm.advance() }`.
- **Animations :**
  - À l'apparition : ensō `scaleEffect` de `OnboardingMetrics.ensoScaleFrom` (0.96) → 1 sur `AppAnimation.slow`, opacité 0 → 1.
  - Glow respirant : un `RadialGradient(FudoColor.accent.opacity(0.18) → .clear)` derrière l'ensō, opacité qui oscille 0.10 ↔ 0.22 en `.easeInOut(duration: OnboardingMetrics.hintPulse).repeatForever(autoreverses: true)`.
  - Hint : même respiration, opacité 0.30 ↔ 0.45, lente. **Jamais un clignotement.**
- **Transition → OB 01a :** crossfade 500 ms (`OnboardingMetrics.videoCrossfade`). La vidéo NE change pas (01a garde le clip `.dojo`) → seuls les hooks se croisent : la scène ne bouge pas, le texte change. `Haptics.light()` au tap.
- **État écrit :** aucun.

---

#### OB 01a — THE TRANSFORMATION

- **Purpose :** La promesse. Pas "tu vas t'améliorer" : *tu ne seras plus le même type*. L'user se voit à gauche (petit, flou, fané) et se voit après (grand, halo vermillon, net). Le futur est le point focal.
- **Copy (verbatim, brief) :**
  - Lead : `IN 30 DAYS,`
  - Climax : `YOU'RE NOT` / `THE SAME GUY.`
  - Wordmark haut : `FUDO`
  - CTA : `Start`
- **UI / layout :**
  - Fond : `WelcomeStageView(clip: .dojo)` (continuité avec le splash) + scrim + vignette.
  - Wordmark en haut, centré, `.fudoFont(.title(20, weight: .bold))`, `.kerning(6)`, `textPrimary`.
  - **La STRIP paysan → sensei**, centrée, hauteur ~200 pt, `GeometryReader` + `.frame` + `.clipped()` :
    - Gauche : `SenseiAssetProvider.image(for: .novice)`, hauteur 130, `.blur(radius: 2.5)`, `.opacity(0.45)`, `.saturation(0.5)` — *le passé*.
    - Milieu : 3 points vermillon croissants (`Circle().fill(FudoColor.accent)`, 3 / 5 / 7 pt, espacés 10) — la progression, pas une flèche.
    - Droite : `SenseiAssetProvider.image(for: .sensei)`, hauteur 175, net, avec derrière un `RadialGradient(FudoColor.accent.opacity(0.30) → .clear)` (halo) et dessous une ombre au sol (`Ellipse().fill(.black.opacity(0.5)).blur(radius: 8).frame(width: 90, height: 12)`) — *le futur, le point focal*.
  - Hook sous la strip, centré, `.multilineTextAlignment(.center)` :
    - `IN 30 DAYS,` → `.fudoFont(.onboardingDisplay(OnboardingMetrics.Hook.transformationLead))` (34), `textPrimary`.
    - `YOU'RE NOT` → `.onboardingDisplay(62)`, `textPrimary`.
    - `THE SAME GUY.` → `.onboardingDisplay(62)`, **`FudoColor.accent`** (le climax).
    - Chaque ligne : `.lineLimit(1).minimumScaleFactor(OnboardingMetrics.Hook.minimumScale)` — Bebas à 62 pt en Dynamic Type accessible déborderait sinon.
  - CTA `Start` : Capsule `FudoColor.accent`, hauteur `FudoSpacing.ctaHeight`, texte `.fudoFont(.headline())` `textPrimary`, en `.safeAreaInset(edge: .bottom)`, marge 20.
- **Animations :**
  - Apparition : la strip monte de 12 pt + fade sur `AppAnimation.slow` ; les 3 lignes du hook arrivent en **cascade** (0 / 0.12 / 0.24 s de délai) en opacité + 8 pt de montée sur `AppAnimation.standard`. Le climax vermillon arrive en dernier : c'est lui qu'on retient.
  - Le halo du sensei respire (opacité 0.22 ↔ 0.34, `hintPulse`).
- **Transition → OB 01b :** `Haptics.light()`, crossfade 500 ms **du clip** (`.dojo` → `.phone`, géré par `WelcomeStageView`) ET des hooks. Sensation : la caméra glisse du dojo au téléphone par terre.
- **État écrit :** aucun.

---

#### OB 01b — THE PAIN

- **Purpose :** Le miroir. Écran volontairement NU : il ne reste que la phrase et le téléphone qui meurt au sol. L'user n'apprend rien, il se reconnaît. Le téléphone est un symbole de distraction, **pas** une promesse de blocage (l'app ne bloque rien).
- **Copy (verbatim, brief) :**
  - Lead : `YOU KNOW` / `WHAT TO DO.`
  - Climax : `YOU JUST DON'T.`
  - Micro-ligne : `Willpower isn't the fix.`
  - CTA : `Continue`
- **UI / layout :**
  - Fond : `WelcomeStageView(clip: .phone)` (lueur bleue mourante → chaleur vermillon) + scrim + vignette.
  - **Pas de wordmark, pas de strip, pas de carte.** L'écran est nu, c'est le point.
  - Hook centré verticalement (légèrement au-dessus du centre, `offset(y: -30)`) :
    - `YOU KNOW` / `WHAT TO DO.` → `.onboardingDisplay(42)`, `textPrimary`.
    - `YOU JUST DON'T.` → `.onboardingDisplay(56)`, `FudoColor.accent`.
  - Micro-ligne sous le hook, `padding(.top, 20)` : `.fudoFont(.body(15))`, `FudoColor.textSecondary`, centrée.
  - CTA `Continue` identique à 01a.
- **Animations :**
  - Cascade des 3 lignes (0 / 0.12 / 0.24 s), la micro-ligne à 0.45 s — elle atterrit après le coup.
  - Rien d'autre ne bouge : la vidéo porte l'écran (bleu → vermillon), le texte l'affirme.
- **Transition → OB 01c :** `Haptics.light()`, crossfade 500 ms (`.phone` → `.doors`).
- **État écrit :** aucun.

---

#### OB 01c — THE MECHANISM

- **Purpose :** Le "comment". On sort du problème : voilà le produit, en une carte. Ton protocole, ton score, 30 jours — et 60 secondes pour le construire. La carte glass MONTRE le produit avant même la première question.
- **Copy (verbatim, brief) :**
  - Lead : `YOUR PROTOCOL.` / `YOUR SCORE.`
  - Climax : `30 DAYS.`
  - Micro-ligne : `60 seconds to build yours.`
  - Carte : `DAY 12` · `OVR 47 ▲` · rows `Cold shower` / `Workout 45 min` / `Read 30 min`
  - CTA : `Continue`
- **UI / layout :**
  - Fond : `WelcomeStageView(clip: .doors)` (portes du dojo + flamme) + scrim + vignette.
  - Hook (haut-centre) : `YOUR PROTOCOL.` / `YOUR SCORE.` → `.onboardingDisplay(46)` `textPrimary` ; `30 DAYS.` → `.onboardingDisplay(72)` `accent`.
  - Micro-ligne : `.fudoFont(.body(15))`, `textSecondary`.
  - **`ProtocolGlassCard`** sous la micro-ligne, `padding(.top, 24)` :
    - Fond : `.background { FudoGlassCapsule() }` **n'est PAS applicable** (c'est une Capsule) → la carte utilise la MÊME recette en `RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)` : `.ultraThinMaterial` + `FudoColor.surfaceGlass`, hairline `FudoColor.borderGlass` 0.5 pt, highlight spéculaire haut. **Fichier séparé** (`ProtocolGlassCard`), pas de duplication de la recette dans l'écran.
    - `.rotationEffect(.degrees(-2.5))` (l'inclinaison du brief).
    - Header : `DAY 12` (`.fudoFont(.label(11, weight: .semibold))`, `.kerning(1.5)`, `textSecondary`) — à gauche ; `OVR 47` + `arrowtriangle.up.fill` à droite (`.fudoFont(.stat(13))`, `FudoColor.accent` pour le texte, **la flèche porte `FudoColor.positive`** — règle des deltas).
    - 3 rows : SF Symbol (`drop.fill`, `figure.strengthtraining.traditional`, `book.fill`, `.fudoFont(.glyph(15))`) + titre (`.fudoFont(.body(14))`, `textPrimary`) + `Circle().fill(FudoColor.accent)` 20 pt avec `checkmark` crème (cochées : on montre un jour qui marche).
    - **Aucune donnée réelle** : ce sont des constantes de démo dans `ProtocolGlassCard` (le joueur n'existe pas encore).
  - CTA `Continue`.
- **Animations :**
  - Cascade du hook (0 / 0.12 / 0.24) ; la carte arrive à 0.45 s : fade + montée 14 pt + un `scaleEffect` 0.97 → 1 sur `AppAnimation.slow`.
  - Les 3 checks de la carte s'allument en cascade (0.7 / 0.8 / 0.9 s), `AppAnimation.standard`. Rien de clinquant : la carte se remplit toute seule, comme une journée réussie.
- **Transition → OB 02 :** `Haptics.light()`, l'Acte 0 **sort** : la vidéo + les hooks fondent (0.5 s) et OB 02 arrive sur `FudoColor.bgPrimary` plat. La rupture est voulue — la pub s'arrête, le diagnostic commence.
- **État écrit :** aucun.

---

- [ ] **Step 1 : Écrire `ProtocolGlassCard.swift`**

Carte de démo, constantes locales (`day = 12`, `ovr = 47`, 3 rows). Documenter : "Demo values on purpose — this is the product's poster, not the player's state (no player exists yet)."

- [ ] **Step 2 : Écrire `SplashScreen.swift` et `WelcomeHookScreen.swift`**

`WelcomeHookScreen` est **data-driven** — un seul fichier pour 01a/01b/01c :

```swift
/// One welcome hook: the internal scale (lead → climax), the micro-line, the CTA,
/// and what the screen shows besides the video. Bebas sizes come from
/// OnboardingMetrics.Hook — the brief's numbers, never re-typed in the view.
struct WelcomeHook {
    enum Feature { case transformationStrip, none, protocolCard }
    let clip: WelcomeClip
    let leadLines: [String]
    let leadSize: CGFloat
    let climaxLines: [String]
    let climaxSize: CGFloat
    let microLine: String?
    let ctaTitle: String
    let showsWordmark: Bool
    let feature: Feature

    static let transformation = WelcomeHook(
        clip: .dojo,
        leadLines: ["IN 30 DAYS,"], leadSize: OnboardingMetrics.Hook.transformationLead,
        climaxLines: ["YOU'RE NOT", "THE SAME GUY."], climaxSize: OnboardingMetrics.Hook.transformationClimax,
        microLine: nil, ctaTitle: "Start", showsWordmark: true, feature: .transformationStrip)

    static let pain = WelcomeHook(
        clip: .phone,
        leadLines: ["YOU KNOW", "WHAT TO DO."], leadSize: OnboardingMetrics.Hook.painLead,
        climaxLines: ["YOU JUST DON'T."], climaxSize: OnboardingMetrics.Hook.painClimax,
        microLine: "Willpower isn't the fix.", ctaTitle: "Continue",
        showsWordmark: false, feature: .none)

    static let mechanism = WelcomeHook(
        clip: .doors,
        leadLines: ["YOUR PROTOCOL.", "YOUR SCORE."], leadSize: OnboardingMetrics.Hook.mechanismLead,
        climaxLines: ["30 DAYS."], climaxSize: OnboardingMetrics.Hook.mechanismClimax,
        microLine: "60 seconds to build yours.", ctaTitle: "Continue",
        showsWordmark: false, feature: .protocolCard)
}
```

⚠️ Le climax est **toujours** `FudoColor.accent`, le lead **toujours** `FudoColor.textPrimary`. La règle vit dans ce fichier, pas dans 3 écrans.

- [ ] **Step 3 : Écrire `OnboardingFlowView.swift` (Acte 0 seulement, le reste en stub)**

```swift
struct OnboardingFlowView: View {
    @State private var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            // ONE stage for the whole welcome act — the screens crossfade OVER it,
            // so the motion never restarts between 00 → 01a → 01b → 01c.
            if viewModel.step.isWelcome {
                WelcomeStageView(clip: viewModel.welcomeClip)
                    .ignoresSafeArea()
                    .transition(.opacity)
                welcomeScrim
            }
            content
                .transition(viewModel.transition)
        }
        .animation(AppAnimation.standard, value: viewModel.step)
    }
}
```

`content` = `switch viewModel.step` → `SplashScreen` / `WelcomeHookScreen(hook:)` / sinon un `Text("Act 1 — next task")` temporaire **qui sera remplacé à l'Acte 1** (ce n'est pas un placeholder livré : la session ne se termine pas ici).

- [ ] **Step 4 : Brancher `RootView` (routage minimal, le hold-lock complet arrive Task 21)**

```swift
// RootView
@State private var flags = OnboardingFlags()

private func refresh() {
    gameStore.processRolloverIfNeeded()
    appState.hasActiveChallenge = gameStore.activeChallenge != nil
    appState.hasCompletedOnboarding = flags.isFullyDone
    evaluateRoute()
}
```

et dans le `fudoCover` : `case .onboarding: OnboardingFlowView(store: gameStore, onFinished: refresh)`.

- [ ] **Step 5 : Compile-only**

Run: `xcodebuild build -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6 : Commit**

```bash
git add FUDO/Features/Onboarding FUDO/App/RootView.swift
git commit -m "feat(onboarding): act 0 — splash and the three welcome hooks over video"
```

- [ ] **Step 7 : GATE ROMAIN — validation simulateur**

Ce que Romain vérifie (Cmd+R, après avoir lancé "Replay onboarding" du menu DEBUG — livré Task 22 ; d'ici là, effacer l'app du simulateur) :
- la vidéo tourne, muette, plein cadre, sans bord noir ;
- **aucune coupe visible** sur la boucle de 01a et 01c ;
- le passage 01a→01b→01c est un fondu continu, pas un flash ;
- les hooks Bebas ne débordent pas, le climax est bien le seul vermillon ;
- "Tap anywhere" respire sans clignoter.

---

# ACTE 1 — Diagnostic & auto-persuasion (OB 02 → OB 10)

**Livrable :** le quiz complet, le stat choc calculé depuis les réponses, la reflection recoupée, l'OVR diagnostic. **Dépend de D1 et D4.**

---

### Task 4 : Le draft de réponses + les moteurs purs (shock math, copy)

**Files:**
- Create: `FUDO/Features/Onboarding/OnboardingDraft.swift`
- Create: `FUDO/Features/Onboarding/ShockMath.swift`
- Create: `FUDO/Features/Onboarding/OnboardingCopy.swift`
- Test: `FUDOTests/ShockMathTests.swift`
- Test: `FUDOTests/OnboardingCopyTests.swift`

**Interfaces:**
- Consumes: `OnboardingAnswers` (existant, **non modifié**), `OVREngine`, `Rank`, `PresetCatalog`.
- Produces: `OnboardingDraft` (+ `Pain`, `AgeBracket`, `Goal`), `ShockMath.Result` / `ShockMath.result(age:scroll:)`, `OnboardingCopy.*`.

**Le barème du choc (D1 en dépend) :**

```
years = hoursPerDay × (horizonAge − pivotAge) / 24
```

| Bracket | pivotAge | horizonAge | span |
|---|---|---|---|
| 13-17 | 15 | 30 | 15 |
| 18-24 | 21 | 30 | 9 |
| 25-34 | 29 | 40 | 11 |
| 35+ | 40 | 50 | 10 |

`hoursPerDay` : <2h → 1.5 · 2-4h → 3 · 4-6h → 5 · 6h+ → 7.

**Table complète des 16 résultats** (à valider par Romain — c'est le nombre que l'user lit) :

| | 13-17 (→30) | 18-24 (→30) | 25-34 (→40) | 35+ (→50) |
|---|---|---|---|---|
| **<2h** | 342 days | 205 days | 251 days | 228 days |
| **2-4h** | 1.9 years | 1.1 years | 1.4 years | 1.3 years |
| **4-6h** | 3.1 years | 1.9 years | 2.3 years | 2.1 years |
| **6h+** | 4.4 years | 2.6 years | 3.2 years | 2.9 years |

> La frame affiche "2.4 years" pour 18-24 + 4-6h ; la formule rend **1.9**. La frame est un mock : le chiffre lu doit être celui des réponses de l'user, pas une valeur de maquette. Si Romain veut taper plus fort, le levier honnête est `horizonAge` (30 → 35 pour les 18-24 donne 2.9), pas un multiplicateur inventé.
>
> **Bascule d'unité** : sous 1 an, on affiche des JOURS ("205 days"). "0.6 years" ne choque personne et sonne faux.

- [ ] **Step 1 : Écrire le test qui échoue — `ShockMathTests`**

```swift
import Testing
@testable import FUDO

struct ShockMathTests {

    @Test func theHeadlineHorizonIsTheBracketsRoundDecade() {
        #expect(ShockMath.result(age: .teen1317, scroll: .fourToSixHours).horizonAge == 30)
        #expect(ShockMath.result(age: .young1824, scroll: .fourToSixHours).horizonAge == 30)
        #expect(ShockMath.result(age: .adult2534, scroll: .fourToSixHours).horizonAge == 40)
        #expect(ShockMath.result(age: .mature35plus, scroll: .fourToSixHours).horizonAge == 50)
    }

    @Test func fourToSixHoursAtTwentyOneCostsNineYearsOfEvenings() {
        let result = ShockMath.result(age: .young1824, scroll: .fourToSixHours)
        // 5 h/day × 9 years / 24 h = 1.875 → 1.9
        #expect(abs(result.years - 1.875) < 0.001)
        #expect(result.headline == "1.9 years")
    }

    @Test func theHeaviestScrollerIsTheHeaviestNumber() {
        #expect(ShockMath.result(age: .teen1317, scroll: .sixHoursPlus).headline == "4.4 years")
    }

    @Test func underOneYearSwitchesToDaysBecauseZeroPointSixDoesNotLand() {
        let result = ShockMath.result(age: .young1824, scroll: .underTwoHours)
        #expect(result.years < 1)
        #expect(result.headline == "205 days")
    }

    @Test func moreScrollingIsAlwaysMoreYears() {
        // Monotonic in the scroll answer: the shock can never reward more scrolling.
        let ordered: [OnboardingAnswers.ScrollTime] = [.underTwoHours, .twoToFourHours,
                                                       .fourToSixHours, .sixHoursPlus]
        for age in AgeBracket.allCases {
            let years = ordered.map { ShockMath.result(age: age, scroll: $0).years }
            #expect(years == years.sorted())
        }
    }
}
```

- [ ] **Step 2 : Lancer — échec attendu**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: FAIL — "cannot find 'ShockMath' in scope".

- [ ] **Step 3 : Écrire `OnboardingDraft.swift`**

```swift
import Foundation

/// The ONE thing the user can't hold alone (OB 02). Not an OVR input — it re-cuts
/// the downstream copy (shock line, reflection fallback).
enum Pain: CaseIterable, Equatable {
    case doomscrolling, wakingUpEarly, trainingConsistently, reading, stayingFocused

    var optionTitle: String {
        switch self {
        case .doomscrolling: "Doomscrolling"
        case .wakingUpEarly: "Waking up early"
        case .trainingConsistently: "Training consistently"
        case .reading: "Reading"
        case .stayingFocused: "Staying focused"
        }
    }
}

/// Age (OB 04) feeds the shock math only — never the OVR.
enum AgeBracket: CaseIterable, Equatable {
    case teen1317, young1824, adult2534, mature35plus

    var optionTitle: String {
        switch self {
        case .teen1317: "13 — 17"
        case .young1824: "18 — 24"
        case .adult2534: "25 — 34"
        case .mature35plus: "35+"
        }
    }
}

/// What he actually wants (OB 07, multi-select). Feeds the reflection only.
enum Goal: CaseIterable, Equatable {
    case leanerBody, earlyWakeUps, killScrolling, readDaily, harderMindset, coldShowers

    var optionTitle: String {
        switch self {
        case .leanerBody: "Leaner, stronger body"
        case .earlyWakeUps: "Master early wake-ups"
        case .killScrolling: "Kill zombie scrolling"
        case .readDaily: "Read every day"
        case .harderMindset: "Harder mindset"
        case .coldShowers: "Cold showers"
        }
    }

    /// The reflection reads as one sentence — "You want a leaner body, no zombie
    /// scrolling, a harder mindset." — so each goal carries its clause form.
    var clause: String {
        switch self {
        case .leanerBody: "a leaner body"
        case .earlyWakeUps: "early wake-ups"
        case .killScrolling: "no zombie scrolling"
        case .readDaily: "reading every day"
        case .harderMindset: "a harder mindset"
        case .coldShowers: "cold showers"
        }
    }
}

/// Answers being collected. Optional until answered — the CTA of each screen is
/// disabled while its own field is nil (never a dead Continue).
struct OnboardingDraft: Equatable {
    var pain: Pain?
    var scrollTime: OnboardingAnswers.ScrollTime?
    var age: AgeBracket?
    var procrastination: OnboardingAnswers.Procrastination?
    var goals: Set<Goal> = []
    var struggle: OnboardingAnswers.Struggle?
    var commitment: OnboardingAnswers.Commitment?

    /// The typed answers OVREngine eats. `commitment` defaults to `.somewhat` (0 pt)
    /// until OB 16 answers it — decision D1: the diagnostic (OB 10) and the
    /// projection (OB 13) show the FLOOR, and the commitment bonus can only raise it.
    /// The scale itself lives in OnboardingAnswers' enums — never re-typed here.
    var answers: OnboardingAnswers {
        OnboardingAnswers(scrollTime: scrollTime ?? .sixHoursPlus,
                          procrastination: procrastination ?? .everyWeek,
                          struggle: struggle ?? .cantEvenStart,
                          commitment: commitment ?? .somewhat)
    }

    /// What the commitment answer is worth, revealed at OB 16/17 (D1).
    var commitmentBonus: Int { commitment?.points ?? 0 }
}
```

- [ ] **Step 4 : Écrire `ShockMath.swift`**

```swift
import Foundation

/// OB 06's number. Pure and self-contained: hours/day × years-to-the-horizon ÷ 24.
/// No study, no source, no claim about the world — just his own two answers,
/// multiplied. That's why it lands.
enum ShockMath {
    struct Result: Equatable {
        let years: Double
        let horizonAge: Int
        /// "2.4 years" — or "205 days" under a year, because "0.6 years" lands on nobody.
        let headline: String
    }

    /// Where the sentence points: the round decade his answers make concrete.
    /// Tunable — this is the honest lever if Romain wants a bigger number.
    private static func pivotAge(_ bracket: AgeBracket) -> Int {
        switch bracket {
        case .teen1317: 15
        case .young1824: 21
        case .adult2534: 29
        case .mature35plus: 40
        }
    }

    private static func horizonAge(_ bracket: AgeBracket) -> Int {
        switch bracket {
        case .teen1317, .young1824: 30
        case .adult2534: 40
        case .mature35plus: 50
        }
    }

    private static func hoursPerDay(_ scroll: OnboardingAnswers.ScrollTime) -> Double {
        switch scroll {
        case .underTwoHours: 1.5
        case .twoToFourHours: 3
        case .fourToSixHours: 5
        case .sixHoursPlus: 7
        }
    }

    static func result(age: AgeBracket, scroll: OnboardingAnswers.ScrollTime) -> Result {
        let horizon = horizonAge(age)
        let span = Double(horizon - pivotAge(age))
        let years = hoursPerDay(scroll) * span / 24
        return Result(years: years, horizonAge: horizon, headline: headline(for: years))
    }

    private static func headline(for years: Double) -> String {
        if years < 1 {
            return "\(Int((years * 365).rounded())) days"
        }
        return "\((years * 10).rounded() / 10) years"
    }
}
```

⚠️ `"\((years * 10).rounded() / 10) years"` rend `"1.9 years"` mais `"2.0 years"` deviendrait `"2.0 years"` — correct. Vérifier qu'un entier ne rende pas `"2.0"` là où on veut `"2"` : le test verrouille `"1.9 years"` ; si Romain préfère "2 years" pour les ronds, c'est un `NumberFormatter` à `maximumFractionDigits: 1` (à trancher au tuning device, pas maintenant).

- [ ] **Step 5 : Écrire le test qui échoue — `OnboardingCopyTests`**

```swift
import Foundation
import Testing
@testable import FUDO

struct OnboardingCopyTests {

    private var draft: OnboardingDraft {
        var draft = OnboardingDraft()
        draft.pain = .trainingConsistently
        draft.scrollTime = .fourToSixHours
        draft.age = .young1824
        draft.procrastination = .everyWeek
        draft.goals = [.leanerBody, .killScrolling, .harderMindset]
        draft.struggle = .threeDaysMax
        return draft
    }

    // MARK: - OB 06

    @Test func theShockLineIsRecutByThePain() {
        let shock = ShockMath.result(age: .young1824, scroll: .fourToSixHours)
        #expect(OnboardingCopy.shockRecut(pain: .trainingConsistently, shock: shock)
                == "That's 1.9 years not spent training.")
        #expect(OnboardingCopy.shockRecut(pain: .reading, shock: shock)
                == "That's 1.9 years of books you'll never read.")
        #expect(OnboardingCopy.shockRecut(pain: .doomscrolling, shock: shock)
                == "That's 1.9 years you will never scroll back.")
    }

    @Test func everyPainHasItsOwnRecutAndNoneIsEmpty() {
        let shock = ShockMath.result(age: .young1824, scroll: .fourToSixHours)
        let lines = Pain.allCases.map { OnboardingCopy.shockRecut(pain: $0, shock: shock) }
        #expect(Set(lines).count == Pain.allCases.count, "each pain must get its own line")
        #expect(lines.allSatisfy { $0.contains("1.9 years") })
    }

    @Test func theShockHeadlineNamesTheHorizonAge() {
        let shock = ShockMath.result(age: .adult2534, scroll: .twoToFourHours)
        #expect(OnboardingCopy.shockLead(shock: shock)
                == "At this pace, by age 40\nyou will have scrolled away")
    }

    // MARK: - OB 09

    @Test func theReflectionJoinsUpToThreeGoalsInAnswerOrder() {
        #expect(OnboardingCopy.reflectionGoals(draft.goals)
                == "You want a leaner body, no zombie scrolling, a harder mindset.")
    }

    @Test func theReflectionCapsAtThreeGoals() {
        // Four selected → the sentence stays a sentence, not a list.
        let goals: Set<Goal> = [.leanerBody, .earlyWakeUps, .killScrolling, .readDaily]
        let line = OnboardingCopy.reflectionGoals(goals)
        #expect(line.components(separatedBy: ",").count == 3)
    }

    @Test func withoutGoalsTheReflectionFallsBackOnThePain() {
        var empty = draft
        empty.goals = []
        #expect(OnboardingCopy.reflectionGoals(empty.goals, fallback: .doomscrolling)
                == "You want to kill doomscrolling.")
    }

    @Test func theEnemyLineComesFromTheStruggle() {
        #expect(OnboardingCopy.enemyLine(.threeDaysMax) == "Your enemy: 3-day consistency.")
        #expect(OnboardingCopy.enemyLine(.startStrongThenQuit) == "Your enemy: week two.")
        #expect(OnboardingCopy.enemyLine(.cantEvenStart) == "Your enemy: the first step.")
    }

    // MARK: - OB 11 (D3)

    @Test func theRecommendedPresetIsAlwaysTheThirtyDayStake() {
        // Every Act-0 hook promises "30 DAYS." — the recommendation never contradicts it.
        for struggle in OnboardingAnswers.Struggle.allCases {
            var d = draft
            d.struggle = struggle
            #expect(OnboardingCopy.recommendedPreset(for: d) == .monk30)
        }
    }

    // MARK: - Dates

    @Test func theProjectionDateIsSpelledOutInEnglish() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        let date = Calendar(identifier: .gregorian).date(from: components) ?? .now
        #expect(OnboardingCopy.longDate(date) == "August 10")
    }
}
```

- [ ] **Step 6 : Lancer — échec attendu**

Expected: FAIL — "cannot find 'OnboardingCopy' in scope".

- [ ] **Step 7 : Écrire `OnboardingCopy.swift`**

```swift
import Foundation

/// Every string the funnel RE-CUTS from the answers. Kept out of the views so the
/// copy is testable and lives in one place — a recut that drifts between two
/// screens is how a funnel stops sounding like it listened.
enum OnboardingCopy {

    // MARK: - OB 06 — the math

    static func shockLead(shock: ShockMath.Result) -> String {
        "At this pace, by age \(shock.horizonAge)\nyou will have scrolled away"
    }

    /// The line that proves the app heard OB 02. Same number, his own wound.
    static func shockRecut(pain: Pain, shock: ShockMath.Result) -> String {
        let amount = shock.headline
        switch pain {
        case .doomscrolling: return "That's \(amount) you will never scroll back."
        case .wakingUpEarly: return "That's \(amount) of mornings you slept through."
        case .trainingConsistently: return "That's \(amount) not spent training."
        case .reading: return "That's \(amount) of books you'll never read."
        case .stayingFocused: return "That's \(amount) your focus belonged to someone else."
        }
    }

    /// The Mao comfort pivot + the 30-day beat (brief, 2026-07-13). Commitment
    /// framing — a stake, never "studies say".
    static let shockPivot = "Monk mode exists exactly for this."
    static let shockStake = """
        Good habit or bad one, it holds the same way: about 30 days without breaking it. \
        That's the minimum stake to prove you own it.
        """

    // MARK: - OB 09 — the reflection

    /// Up to three goals, in enum order (stable — a Set has none), joined as ONE
    /// sentence. Four selections would read as a shopping list; three reads as a man.
    static func reflectionGoals(_ goals: Set<Goal>, fallback: Pain? = nil) -> String {
        let clauses = Goal.allCases.filter { goals.contains($0) }.prefix(3).map(\.clause)
        guard !clauses.isEmpty else {
            guard let fallback else { return "You want out." }
            return painWant(fallback)
        }
        return "You want \(clauses.joined(separator: ", "))."
    }

    private static func painWant(_ pain: Pain) -> String {
        switch pain {
        case .doomscrolling: "You want to kill doomscrolling."
        case .wakingUpEarly: "You want to own your mornings."
        case .trainingConsistently: "You want to train without missing."
        case .reading: "You want to read every day."
        case .stayingFocused: "You want your focus back."
        }
    }

    static func enemyLine(_ struggle: OnboardingAnswers.Struggle) -> String {
        switch struggle {
        case .startStrongThenQuit: "Your enemy: week two."
        case .threeDaysMax: "Your enemy: 3-day consistency."
        case .cantEvenStart: "Your enemy: the first step."
        }
    }

    static let reflectionClose = "Your protocol will be built on exactly that."

    // MARK: - OB 11 — the recommendation (D3)

    /// Always the 30-day stake. Every welcome hook says "30 DAYS." and the shock
    /// screen calls 30 days the minimum stake — recommending 75 would call the
    /// funnel a liar. The chips still offer 60 / 75 / 90 to whoever wants them.
    static func recommendedPreset(for draft: OnboardingDraft) -> ChallengePreset { .monk30 }

    // MARK: - Dates

    /// "August 10" — EN-only app, so the locale is pinned and never follows the device.
    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    /// "7:00 AM" — the reminder hour, same pinned locale.
    static func clockTime(minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 8 : Lancer les tests — ils doivent compiler**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 9 : Commit**

```bash
git add FUDO/Features/Onboarding FUDOTests/ShockMathTests.swift FUDOTests/OnboardingCopyTests.swift
git commit -m "feat(onboarding): answer draft, shock math and the copy recut engine"
```

---

### Task 5 : `OnboardingViewModel` — la machine, le spam guard, les checkpoints

**Files:**
- Create: `FUDO/Features/Onboarding/OnboardingViewModel.swift`
- Test: `FUDOTests/OnboardingViewModelTests.swift`

**Interfaces:**
- Consumes: `OnboardingStep`, `OnboardingDraft`, `OnboardingFlags`, `OnboardingCopy`, `ShockMath`, `OnboardingMetrics` (Tasks 1 & 4) ; `GameStore`, `OVREngine`, `ChallengeSetupViewModel`, `PresetCatalog`.
- Produces: `OnboardingViewModel` — API consommée par TOUS les écrans :
  - `var step: OnboardingStep` · `var draft: OnboardingDraft` · `var direction: Direction`
  - `var transition: AnyTransition` · `var welcomeClip: WelcomeClip`
  - `func advance()` · `func back()` · `var canAdvance: Bool`
  - `var setup: ChallengeSetupViewModel` (possédé, créé à l'entrée d'OB 11)
  - `var shock: ShockMath.Result?` · `var diagnosticOVR: Int` · `var projectedOVR: Double` · `var projectionDate: Date` · `var projectedRank: Rank`
  - `func signContract()` · `func passPaywall()` · `func commitChallenge() async` · `func finish()`

**Points de conception :**

1. **`canAdvance` est par étape** — le CTA est grisé (`FudoColor.bgCard` + bordure) tant que la réponse de CET écran manque. Jamais de bouton mort (piège connu) :
```swift
var canAdvance: Bool {
    switch step {
    case .painPoint: draft.pain != nil
    case .scrollHours: draft.scrollTime != nil
    case .age: draft.age != nil
    case .procrastination: draft.procrastination != nil
    case .goals: !draft.goals.isEmpty
    case .struggle: draft.struggle != nil
    case .commitment: draft.commitment != nil
    case .compose: setup.canCommit
    case .contract: hasSignature
    default: true
    }
}
```

2. **Le ctaSpamGuard** (RiteOff `commit(progress:)`) — pas d'horloge, un booléen :
```swift
/// A second tap fired inside the 0.5 s transition is the user's finger, not his
/// intent: it would skip a whole screen. Guard = a flag the transition owns.
private(set) var isAdvancing = false

func advance() {
    guard !isAdvancing, canAdvance, let next = step.next else { return }
    isAdvancing = true
    Haptics.light()
    direction = .forward
    step = next
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(OnboardingMetrics.ctaGuard))
        isAdvancing = false
    }
}
```
`back()` suit le même garde, avec `direction = .backward` et `step.previous` (et seulement si `step.showsBack`).

3. **La transition** — direction-aware, une seule règle pour tout le funnel :
```swift
enum Direction { case forward, backward }

/// Horizontal slide + fade: the funnel reads as forward motion. The welcome act
/// overrides it with a pure crossfade (the video must never slide).
var transition: AnyTransition {
    if step.isWelcome { return .opacity }
    let insertion: Edge = direction == .forward ? .trailing : .leading
    let removal: Edge = direction == .forward ? .leading : .trailing
    return .asymmetric(insertion: .move(edge: insertion).combined(with: .opacity),
                       removal: .move(edge: removal).combined(with: .opacity))
}
```

4. **Les dérivations passent TOUTES par le moteur** — zéro calcul local :
```swift
/// D1: the floor. `draft.answers` defaults commitment to `.somewhat` (0 pt) until
/// OB 16 answers it, so this number can only go UP later — never down.
var diagnosticOVR: Int { OVREngine.displayedOVR(OVREngine.startingOVR(from: draft.answers)) }

var projectedOVR: Double {
    OVREngine.project(from: OVREngine.startingOVR(from: draft.answers), days: setup.durationDays)
}

var projectedRank: Rank { OVREngine.rank(forOVR: projectedOVR) }

/// Day 1 is today → the last day is today + duration − 1. Same derivation as
/// ChallengeSetupViewModel.endDate — read from the setup VM, never re-computed.
var projectionDate: Date { setup.endDate }
```

5. **`signContract()` = checkpoint 1** :
```swift
/// Checkpoint 1 (kill-safety): the player becomes REAL here — his OVR exists even
/// if he kills the app at the paywall. The CHALLENGE does not: its day-1 clock
/// must not tick while he's blocked behind a paywall he hasn't passed.
func signContract() {
    let startingOVR = OVREngine.startingOVR(from: draft.answers)
    store.ensurePlayer(startingOVR: startingOVR)
    flags.contract = ContractSnapshot(
        startingOVR: startingOVR,
        projectedOVR: projectedOVR,
        preset: setup.selectedPreset,
        durationDays: setup.durationDays,
        reminderMinutes: setup.reminderMinutes,
        rules: setup.enabledRules.map { .init(title: $0.title, iconName: $0.iconName) })
    advance()
}
```

6. **`commitChallenge()` = le vrai travail derrière l'étape 1 du loader OB 19** :
```swift
/// OB 19's "Saving your protocol" is not a lie: the challenge is created HERE,
/// after the paywall, so day 1 starts when he actually reaches the dojo.
func commitChallenge() {
    guard let contract = flags.contract else { return }
    store.ensurePlayer(startingOVR: contract.startingOVR)
    store.startChallenge(preset: contract.preset,
                         durationDays: contract.durationDays,
                         rules: contract.rules.map { RuleDraft(title: $0.title, iconName: $0.iconName) },
                         reminderMinutes: contract.reminderMinutes)
}
```

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import Foundation
import SwiftData
import Testing
@testable import FUDO

@MainActor
@Suite(.serialized)
struct OnboardingViewModelTests {

    private func makeViewModel() throws -> (OnboardingViewModel, GameStore, OnboardingFlags) {
        // NEVER build a container here — SwiftDataTestSupport owns the single one
        // (iOS 17 multi-container crash, carnet 2026-07-12).
        let context = try SwiftDataTestSupport.freshContainer().mainContext
        let store = GameStore(modelContext: context)
        let flags = OnboardingFlags(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
        return (OnboardingViewModel(store: store, flags: flags), store, flags)
    }

    @Test func aFreshFunnelOpensOnTheSplashAndBlocksBack() throws {
        let (vm, _, _) = try makeViewModel()
        #expect(vm.step == .splash)
        vm.back()
        #expect(vm.step == .splash, "there is nothing behind the splash")
    }

    @Test func theCtaIsDeadUntilTheQuestionIsAnswered() throws {
        let (vm, _, _) = try makeViewModel()
        vm.jump(to: .painPoint)
        #expect(vm.canAdvance == false)
        vm.advance()
        #expect(vm.step == .painPoint, "an unanswered question never advances")
        vm.draft.pain = .doomscrolling
        #expect(vm.canAdvance)
        vm.advance()
        #expect(vm.step == .scrollHours)
    }

    @Test func theSpamGuardSwallowsTheSecondTap() throws {
        let (vm, _, _) = try makeViewModel()
        vm.jump(to: .painPoint)
        vm.draft.pain = .doomscrolling
        vm.advance()
        vm.advance()   // the same finger, 30 ms later
        #expect(vm.step == .scrollHours, "a double tap must not skip a screen")
    }

    @Test func goalsNeedAtLeastOneSelection() throws {
        let (vm, _, _) = try makeViewModel()
        vm.jump(to: .goals)
        #expect(vm.canAdvance == false)
        vm.draft.goals = [.leanerBody]
        #expect(vm.canAdvance)
    }

    // MARK: - D1: the commitment bonus can only raise the number

    @Test func theDiagnosticShowsTheFloorAndTheCommitmentRaisesIt() throws {
        let (vm, _, _) = try makeViewModel()
        vm.draft.scrollTime = .twoToFourHours       // +3
        vm.draft.procrastination = .everyMonth      // +1
        vm.draft.struggle = .threeDaysMax           // +1
        // commitment unanswered → .somewhat (0) → 40 + 5 = 45
        #expect(vm.diagnosticOVR == 45)

        vm.draft.commitment = .extremely            // +2
        #expect(vm.diagnosticOVR == 47, "the commitment bonus lifts the floor, never lowers it")
    }

    @Test func theDiagnosticNeverLeavesTheEngineBand() throws {
        let (vm, _, _) = try makeViewModel()
        for scroll in OnboardingAnswers.ScrollTime.allCases {
            for procrastination in OnboardingAnswers.Procrastination.allCases {
                for struggle in OnboardingAnswers.Struggle.allCases {
                    vm.draft.scrollTime = scroll
                    vm.draft.procrastination = procrastination
                    vm.draft.struggle = struggle
                    #expect(vm.diagnosticOVR >= GameConfig.baseOVRMin)
                    #expect(vm.diagnosticOVR <= GameConfig.baseOVRMax)
                }
            }
        }
    }

    // MARK: - The projection comes from the engine

    @Test func theProjectionIsTheEnginesAndTheRankIsReadFromIt() throws {
        let (vm, _, _) = try makeViewModel()
        vm.draft.scrollTime = .twoToFourHours
        vm.draft.procrastination = .everyMonth
        vm.draft.struggle = .cantEvenStart
        let base = OVREngine.startingOVR(from: vm.draft.answers)

        #expect(vm.projectedOVR == OVREngine.project(from: base, days: vm.setup.durationDays))
        #expect(vm.projectedRank == Rank.from(ovr: vm.projectedOVR))
        // 44 → 30 perfect days lands in the Warrior band, never Master (frame bug).
        #expect(vm.projectedRank == .warrior)
    }

    @Test func theProjectionDateIsTheLastDayOfTheChallenge() throws {
        let (vm, store, _) = try makeViewModel()
        let expected = store.displayCalendar.date(byAdding: .day, value: vm.setup.durationDays - 1,
                                                  to: store.effectiveToday)
        #expect(vm.projectionDate == expected)
    }

    // MARK: - Checkpoints

    @Test func signingCreatesThePlayerButNotTheChallenge() throws {
        let (vm, store, flags) = try makeViewModel()
        vm.draft.scrollTime = .underTwoHours
        vm.draft.procrastination = .stoppedLyingToMyself
        vm.draft.struggle = .startStrongThenQuit
        vm.draft.commitment = .extremely
        vm.jump(to: .contract)
        vm.registerSignature()
        vm.signContract()

        #expect(store.player != nil, "the OVR must survive a kill at the paywall")
        #expect(store.activeChallenge == nil, "day 1 must not tick behind the paywall")
        #expect(flags.contract?.durationDays == 30)
        #expect(vm.step == .paywall)
    }

    @Test func theContractCannotBeSignedWithoutAStroke() throws {
        let (vm, store, _) = try makeViewModel()
        vm.jump(to: .contract)
        #expect(vm.canAdvance == false)
        #expect(store.player == nil)
    }

    @Test func theLoaderCommitsTheChallengeAfterThePaywall() throws {
        let (vm, store, flags) = try makeViewModel()
        vm.draft.scrollTime = .underTwoHours
        vm.draft.procrastination = .stoppedLyingToMyself
        vm.draft.struggle = .startStrongThenQuit
        vm.jump(to: .contract)
        vm.registerSignature()
        vm.signContract()
        vm.passPaywall()
        #expect(flags.hasCompletedOnboarding, "checkpoint 2")
        #expect(flags.isFullyDone == false, "the hold-lock still holds")

        vm.commitChallenge()
        #expect(store.activeChallenge?.durationDays == 30)
        #expect(store.activeChallenge?.startDate == store.effectiveToday, "day 1 is today (D2)")
    }

    @Test func finishingOpensTheAppAndBurnsTheDraft() throws {
        let (vm, _, flags) = try makeViewModel()
        vm.finish()
        #expect(flags.isFullyDone)
        #expect(flags.contract == nil)
    }
}
```

- [ ] **Step 2 : Lancer — échec attendu**

Expected: FAIL — "cannot find 'OnboardingViewModel' in scope".

- [ ] **Step 3 : Écrire `OnboardingViewModel.swift`**

`@MainActor @Observable final class OnboardingViewModel`, avec les 6 points de conception ci-dessus. Détails restants :
- `init(store: GameStore, flags: OnboardingFlags = OnboardingFlags())` → `step = flags.resumeStep` (reprise kill-safety), `setup = ChallengeSetupViewModel(store: store, recommendedPreset: .monk30)`.
- ⚠️ `recommendedPreset` doit être calculé quand le draft est prêt : `OnboardingCopy.recommendedPreset(for: draft)` est appelé **à l'entrée d'OB 11** (`func prepareCompose()`, qui recrée le `setup` si le preset reco a changé). En D3 la réponse est constante (`.monk30`) → le `setup` de l'init est déjà correct ; la fonction existe pour que le jour où D3 bouge, un seul point change.
- `func jump(to:)` — **`#if DEBUG` uniquement** (les tests et le menu DEBUG s'en servent, la prod n'en a pas le droit).
- `private(set) var hasSignature = false` + `func registerSignature()` / `func clearSignature()`.
- `var welcomeClip: WelcomeClip` → `.dojo` pour `.splash`/`.transformation`, `.phone` pour `.pain`, `.doors` pour `.mechanism`.
- `func passPaywall()` → `flags.hasCompletedOnboarding = true` ; `advance()`.
- `func finish()` → `flags.markFullyCompleted()` ; appelle `onFinished` (injecté par `OnboardingFlowView` → `RootView.refresh`).

- [ ] **Step 4 : Ajouter `isWelcome` à `OnboardingStep`**

```swift
extension OnboardingStep {
    /// The video act — crossfade only, never a slide.
    var isWelcome: Bool {
        switch self {
        case .splash, .transformation, .pain, .mechanism: true
        default: false
        }
    }
}
```

- [ ] **Step 5 : Compile-only**

Run: `xcodebuild build-for-testing -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6 : Commit**

```bash
git add FUDO/Features/Onboarding FUDOTests/OnboardingViewModelTests.swift
git commit -m "feat(onboarding): view model — state machine, spam guard, kill-safety checkpoints"
```

---

### Task 6 : Le squelette partagé (scaffold, barre, option row)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/OnboardingProgressBar.swift`
- Create: `FUDO/Features/Onboarding/Views/OptionRow.swift`
- Create: `FUDO/Features/Onboarding/Views/OnboardingScaffold.swift`

**Interfaces:**
- Produces: `OnboardingProgressBar(fraction: Double?)`, `OptionRow(title:subtitle:isSelected:action:)`, `OnboardingScaffold(step:eyebrow:title:subtitle:ctaTitle:canAdvance:onBack:onAdvance:content:)`.

**`OnboardingProgressBar` :** `Capsule` track `FudoColor.border` hauteur 3, remplissage `FudoColor.accent`, largeur = `fraction × width` via `GeometryReader`. `.animation(AppAnimation.standard, value: fraction)` → la barre GLISSE d'un écran à l'autre (c'est le seul feedback de progression). `fraction == nil` → la barre n'est pas rendue du tout (pas d'espace réservé : les frames sans barre remontent le contenu).

**`OptionRow` :** hauteur 56 (`RuleRowEditor` fait déjà 56 — même rythme), `RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)`.
- Idle : fill `FudoColor.bgCard`, bordure `FudoColor.border` 1 pt, texte `textPrimary` `.fudoFont(.body(16))`.
- **Sélectionné** : fill `FudoColor.accentDeep.opacity(0.35)` (le rouge sombre des frames), bordure `FudoColor.accent` **1.5 pt**, texte `textPrimary`.
- `subtitle` optionnel (OB 16 : "Extremely — start today" est un titre entier, pas un sous-titre → non utilisé pour l'instant, mais l'API le porte pour les rows à 2 lignes).
- `Haptics.light()` au tap, `.animation(AppAnimation.standard, value: isSelected)`.
- `.buttonStyle(.plain)`, toute la row tappable.

**`OnboardingScaffold` :** le gabarit de 10 écrans (OB 02→08, 16, et par extension 10/13/15).
```
VStack(alignment: .leading, spacing: 0)
  header:  ZStack { back chevron (si step.showsBack) | OnboardingProgressBar }   ← .padding(.top, 8)
  eyebrow: .fudoFont(.label(13, weight: .bold)) .kerning(2) FudoColor.accent      ← .padding(.top, 56)
  title:   .fudoFont(.title(28, weight: .bold)) textPrimary                       ← .padding(.top, 10)
  subtitle (optionnel): .fudoFont(.body(15)) textSecondary                        ← .padding(.top, 6)
  content                                                                         ← .padding(.top, 32)
  Spacer()
  CTA (safeAreaInset .bottom)
```
- Marge écran `FudoSpacing.screenMargin` (20) partout.
- Le chevron : `Image(systemName: "chevron.left").fudoFont(.headline())`, `textSecondary`, zone de tap élargie (`.padding(.vertical, 8).padding(.trailing, 12)`), `Haptics.light()`.
- Le CTA : Capsule, `ctaHeight` 56 ; actif → fill `FudoColor.accent` ; inactif → fill `FudoColor.bgCard` + bordure `border` + texte `textSecondary`, `.disabled(true)`.
- ⚠️ **La barre et le chevron partagent la ligne du haut** (frames) : le chevron est à gauche, la barre commence après lui. Quand `showsBack == false`, la barre prend toute la largeur (frames OB 09/16/17 ✓).

- [ ] **Step 1 : Écrire les 3 fichiers**
- [ ] **Step 2 : Compile-only** — Run: `xcodebuild build -scheme FUDO -destination 'generic/platform=iOS Simulator'` — Expected: BUILD SUCCEEDED.
- [ ] **Step 3 : Commit**

```bash
git add FUDO/Features/Onboarding/Views
git commit -m "feat(onboarding): shared scaffold, progress bar and option row"
```

---

### Task 7 : OB 02 → OB 05 — le quiz (single choice)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/SingleChoiceScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionRow` (Task 6) ; `OnboardingViewModel` (Task 5).
- Produces: `SingleChoiceScreen<Option: Hashable>(eyebrow:title:options:titleFor:selection:onAdvance:onBack:)` — **un seul fichier pour 5 écrans** (OB 02, 03, 04, 05, 08, 16).

Le générique évite 6 copies du même écran. La description de chaque question vit dans l'écran appelant (le `switch` de `OnboardingFlowView`), pas dans une table anonyme : le lecteur voit la question ET ses options au même endroit.

---

#### OB 02 — PAIN POINT

- **Purpose :** La première question est un aveu. Il nomme la chose qu'il ne tient pas seul — et tout le reste du tunnel lui reparlera de CETTE chose. C'est là que l'app arrête d'être une pub et commence à écouter.
- **Copy (verbatim) :**
  - Eyebrow : `START HERE`
  - Titre : `What's the ONE thing\nyou can't control alone?`
  - Options : `Doomscrolling` · `Waking up early` · `Training consistently` · `Reading` · `Staying focused`
  - CTA : `Continue`
- **UI :** `OnboardingScaffold` + 5 `OptionRow` (spacing 10). Barre 1/15. Chevron ✓.
- **Animations :** apparition → les rows arrivent en cascade (délai 0.04 s × index), fade + 8 pt de montée, `AppAnimation.standard`. Sélection → fill + bordure animés, `Haptics.light()`.
- **Transition → OB 03 :** slide gauche + fade, 0.5 s, `Haptics.light()`.
- **État écrit :** `draft.pain`. → recoupe OB 06 (shock line), OB 09 (fallback), OB 11 (via `recommendedPreset`).

---

#### OB 03 — SCROLL HOURS

- **Purpose :** Il donne le chiffre qui va le frapper 3 écrans plus loin. Il ne le sait pas encore. Le ton ("BE HONEST") lui interdit de tricher — et s'il triche, le nombre baisse : la punition est intégrée.
- **Copy :** Eyebrow `BE HONEST` · Titre `How many hours a day\ndo you scroll?` · Options `Less than 2 hours` · `2 — 4 hours` · `4 — 6 hours` · `6+ hours` · CTA `Continue`.
- **UI :** identique à OB 02, 4 rows. Barre 2/15.
- **État écrit :** `draft.scrollTime` → **OVR de départ** (`OnboardingAnswers.ScrollTime.points` : +4/+3/+1/+0) **et** shock math (heures/jour).

---

#### OB 04 — AGE

- **Purpose :** La question la plus banale du tunnel — et la munition du choc. "QUICK ONE" désamorce : il répond sans réfléchir, donc honnêtement.
- **Copy :** Eyebrow `QUICK ONE` · Titre `How old are you?` · Options `13 — 17` · `18 — 24` · `25 — 34` · `35+` · CTA `Continue`.
- **UI :** identique. Barre 3/15.
- **État écrit :** `draft.age` → **shock math uniquement**, jamais l'OVR.

---

#### OB 05 — PROCRASTINATION

- **Purpose :** "NO JUDGMENT" : on lui donne la permission de dire la vérité la plus honteuse ("every single week"). Répondre honnêtement ici = il s'est déjà avoué le problème, l'app n'a plus qu'à le lui rendre.
- **Copy :** Eyebrow `NO JUDGMENT` · Titre `How often do you say\n"I'll start Monday"?` · Options `Every single week` · `Every month` · `I stopped lying to myself` · CTA `Continue`.
- **UI :** identique, 3 rows. Barre 4/15.
- **État écrit :** `draft.procrastination` → OVR de départ (+0/+1/+2).

- [ ] **Step 1 : Écrire `SingleChoiceScreen.swift`**
- [ ] **Step 2 : Câbler OB 02→05 dans le `switch` d'`OnboardingFlowView`**

```swift
case .painPoint:
    SingleChoiceScreen(step: .painPoint, eyebrow: "START HERE",
                       title: "What's the ONE thing\nyou can't control alone?",
                       options: Pain.allCases, titleFor: \.optionTitle,
                       selection: $viewModel.draft.pain,
                       onAdvance: viewModel.advance, onBack: viewModel.back)
```
(idem pour `.scrollHours` / `.age` / `.procrastination` avec leurs enums.)

⚠️ `OnboardingAnswers.ScrollTime` etc. n'ont pas d'`optionTitle` — les libellés d'options vivent dans une extension **côté onboarding** (`OnboardingDraft.swift`), jamais dans `Core/Game/OnboardingAnswers.swift` (Core ne connaît pas la copy UI) :
```swift
extension OnboardingAnswers.ScrollTime {
    var optionTitle: String {
        switch self {
        case .underTwoHours: "Less than 2 hours"
        case .twoToFourHours: "2 — 4 hours"
        case .fourToSixHours: "4 — 6 hours"
        case .sixHoursPlus: "6+ hours"
        }
    }
}
```
⚠️ **Ordre d'affichage** : les frames listent du plus vertueux au pire (Less than 2 → 6+) et du pire au meilleur pour la procrastination (Every single week → I stopped lying). L'ordre des `allCases` doit matcher la frame, pas le barème. `ScrollTime.allCases` = `[.underTwoHours, .twoToFourHours, .fourToSixHours, .sixHoursPlus]` ✓ ; `Procrastination.allCases` = `[.stoppedLyingToMyself, .everyMonth, .everyWeek]` ✗ → l'écran passe une liste explicite `[.everyWeek, .everyMonth, .stoppedLyingToMyself]`. **Ne pas réordonner l'enum** (le barème le lit).

- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 02-05 — the diagnostic questions"
```

---

### Task 8 : OB 06 — le stat choc

**Files:**
- Create: `FUDO/Features/Onboarding/Views/ShockStatScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

- **Purpose :** Le AHA, à moins d'une minute de l'ouverture. Il n'a pas lu une statistique : il a lu SA multiplication. Puis le pivot Mao : on ne le laisse pas dans la douleur, on lui dit que le monk mode existe exactement pour ça — et pourquoi 30 jours est la mise minimale.
- **Copy (verbatim, tout dérivé) :**
  - Eyebrow : `THE MATH`
  - Lead : `OnboardingCopy.shockLead(shock:)` → ex. `At this pace, by age 30\nyou will have scrolled away`
  - **Le nombre** : `shock.headline` → ex. `1.9 years`
  - Suite : `of your life.`
  - Recoupe (vermillon) : `OnboardingCopy.shockRecut(pain:shock:)` → ex. `That's 1.9 years not spent training.`
  - Pivot : `OnboardingCopy.shockPivot` → `Monk mode exists exactly for this.`
  - **Beat 30 jours** (`OnboardingCopy.shockStake`) : `Good habit or bad one, it holds the same way: about 30 days without breaking it. That's the minimum stake to prove you own it.`
  - CTA : `Continue`
- **UI / layout :**
  - Fond : `FudoColor.bgPrimary` + un **wash vermillon** en haut (`LinearGradient(FudoColor.accentDeep.opacity(0.35) → .clear, .top → .center)`) — la frame est plus chaude que les écrans de quiz. C'est le seul écran de l'Acte 1 avec un fond teinté.
  - Lead : `.fudoFont(.body(19))`, `textPrimary`.
  - **Le nombre** : `.fudoFont(.ovr(56))` `FudoColor.accent` — `ovr` porte `monospacedDigit` (le compteur ne tremble pas) et le plafond serré 1.15× (il vit dans une ligne fixe). `.minimumScaleFactor(0.6)` (`"342 days"` est plus large que `"1.9 years"`).
  - `of your life.` : `.fudoFont(.title(24, weight: .bold))`, `textPrimary`.
  - Recoupe : `.fudoFont(.body(15, weight: .medium))`, `FudoColor.accent`, `padding(.top, 16)`.
  - Séparateur : `Rectangle().fill(FudoColor.accent).frame(width: 32, height: 2)`, `padding(.top, 28)`.
  - Pivot : `.fudoFont(.body(15))`, `textSecondary`, `padding(.top, 22)`.
  - Beat 30 j : `.fudoFont(.caption(13))`, `textSecondary.opacity(0.85)`, `padding(.top, 8)`.
  - Barre 5/15, chevron ✓.
- **Animations :**
  - **Le count-up** (`OnboardingMetrics.countUpDuration` = 1.2 s) : le nombre monte de 0 à sa valeur, sobre — `.easeOut`, aucun rebond, aucun scale. Implémentation : un `@State private var displayed: Double = 0` + `withAnimation(.easeOut(duration: 1.2)) { displayed = shock.years }` sur un `Text` qui reformate `displayed` — ⚠️ SwiftUI n'anime pas un `Text` interpolé : utiliser un `AnimatableModifier`/`Animatable` custom (`CountUpText`) OU une `TimelineView`. **Reco : un petit `CountUpText: View, Animatable` local au fichier** (`var animatableData: Double`), qui reformate via la même règle que `ShockMath.headline` — donc `ShockMath.headline(for:)` doit devenir `static` accessible (`internal`), pas `private`. À ajuster en Task 4 si déjà écrit privé.
  - `Haptics.medium()` **une fois**, quand le count-up atteint sa valeur (le coup arrive avec le nombre, pas avant).
  - La recoupe apparaît APRÈS le count-up (délai 1.2 s), fade + 8 pt. Le pivot et le beat à 1.6 s / 1.8 s. La séquence entière ≈ 2 s : il lit le chiffre, encaisse, puis on lui tend la main.
  - **Le CTA reste disponible dès l'entrée** — jamais de bouton verrouillé pendant une animation (piège connu).
- **Transition → OB 07 :** slide + fade standard.
- **État écrit :** aucun (écran de valeur, pure lecture du draft).

- [ ] **Step 1 : Rendre `ShockMath.headline(for:)` internal + écrire `CountUpText`**
- [ ] **Step 2 : Écrire `ShockStatScreen.swift` + câbler le `switch`**
- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 06 — the shock stat, count-up and the 30-day stake"
```

---

### Task 9 : OB 07 → OB 09 — cibles, problème, reflection

**Files:**
- Create: `FUDO/Features/Onboarding/Views/MultiChoiceScreen.swift`
- Create: `FUDO/Features/Onboarding/Views/ReflectionScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

---

#### OB 07 — GOALS (multi-select)

- **Purpose :** Après le coup, on le laisse se projeter. Il coche ce qu'il VEUT — c'est lui qui écrit la promesse, l'app ne fait que la lui relire deux écrans plus loin.
- **Copy :** Eyebrow `YOUR TARGETS` · Titre `What do you actually\nwant?` · Sous-titre `Pick all that apply` · Options `Leaner, stronger body` · `Master early wake-ups` · `Kill zombie scrolling` · `Read every day` · `Harder mindset` · `Cold showers` · CTA `Continue`.
- **UI :** `OnboardingScaffold` + 6 `OptionRow` multi-sélection (spacing 10). Barre 6/15, chevron ✓.
- **Animations :** cascade d'entrée ; chaque tap toggle avec `Haptics.light()` — sélection multiple, aucun désélection forcée.
- **CTA :** grisé tant que `draft.goals.isEmpty`.
- **État écrit :** `draft.goals: Set<Goal>` → OB 09 (la phrase).

---

#### OB 08 — STRUGGLE

- **Purpose :** La dernière vérité, la plus utile : *comment* il échoue. C'est la réponse qui devient "ton ennemi" à l'écran suivant, et qui pèse sur l'OVR de départ.
- **Copy :** Eyebrow `THE REAL TALK` · Titre `What's your real problem?` · Options `I start strong, then quit` · `I'm consistent 3 days max` · `I can't even get started` · CTA `Continue`.
- **UI :** `SingleChoiceScreen`, 3 rows. Barre 7/15, chevron ✓. Ordre = celui de la frame (`[.startStrongThenQuit, .threeDaysMax, .cantEvenStart]` — identique à `allCases` ✓).
- **État écrit :** `draft.struggle` → OVR de départ (+2/+1/+0) **et** `OnboardingCopy.enemyLine`.

---

#### OB 09 — REFLECTION (le mur)

- **Purpose :** Se sentir ENTENDU. L'app lui rend ses propres mots, sans les commenter. Pas de retour possible (aucun chevron) : ce qu'il a dit est dit. Et le CTA n'est plus "Continue" — c'est lui qui ordonne : "Build my protocol".
- **Copy (verbatim, dérivé) :**
  - Eyebrow : `GOT IT`
  - Phrase : `OnboardingCopy.reflectionGoals(draft.goals, fallback: draft.pain)` → ex. `You want a leaner body, no zombie scrolling, a harder mindset.`
  - Ennemi (vermillon) : `OnboardingCopy.enemyLine(struggle)` → ex. `Your enemy: 3-day consistency.`
  - Clôture : `OnboardingCopy.reflectionClose` → `Your protocol will be built on exactly that.`
  - CTA : `Build my protocol`
- **UI / layout :**
  - Fond : `bgPrimary` + wash vermillon haut (même recette qu'OB 06 — les 2 écrans de valeur de l'acte se répondent).
  - **Barre SANS chevron** (7… → 8/15) — la barre prend toute la largeur.
  - Phrase : `.fudoFont(.title(26, weight: .bold))`, `textPrimary`, `.lineSpacing(4)`. Le retour à la ligne est naturel (pas de `\n` : la phrase est dérivée).
  - Ennemi : `.fudoFont(.title(26, weight: .bold))`, `FudoColor.accent`, `padding(.top, 32)`.
  - Clôture : `.fudoFont(.body(15))`, `textSecondary`, `padding(.top, 26)`.
- **Animations :** la phrase arrive (fade + 10 pt) à 0 s ; l'ennemi à 0.5 s avec `Haptics.medium()` — c'est le beat ; la clôture à 1.0 s. Rien ne bouge ensuite.
- **Transition → OB 10 :** slide + fade.
- **État écrit :** aucun.

- [ ] **Step 1 : Écrire `MultiChoiceScreen.swift` et `ReflectionScreen.swift` + câbler**
- [ ] **Step 2 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3 : Commit**

```bash
git commit -am "feat(onboarding): OB 07-09 — targets, struggle and the reflection wall"
```

---

### Task 10 : OB 10 — l'OVR diagnostic (split OVR, beat 1)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/DiagnosticScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

- **Purpose :** Il reçoit un **nombre qui le décrit**. Pas un score gagné : un point de départ, et le fait que presque personne n'en bouge. La menace et l'invitation dans la même phrase. C'est le premier des deux beats OVR (l'autre est la projection, OB 13) — on les sépare exprès : ici "voilà où tu es", là-bas "voilà où tu vas".
- **Copy (verbatim) :**
  - Eyebrow : `YOUR STARTING POINT`
  - Nombre : `\(viewModel.diagnosticOVR)` → ex. `43`
  - Rang : `NOVICE` (dérivé : `Rank.from(ovr:)` → nom via un helper local, cf. ci-dessous)
  - Titre : `This is where\neveryone starts.`
  - Corps : `Almost no one moves from here.\nThe protocol is how you do.`
  - CTA : `Continue`
- **UI / layout :**
  - Barre 9/15, chevron ✓.
  - **Hero** (hauteur ~250) : `HStack` — à gauche le paysan (`SenseiAssetProvider.image(for: .novice)`, `.scaledToFit().frame(height: 240)`), à droite le nombre et le rang :
    - Nombre : `.fudoFont(.ovr(76))`, `textPrimary` (crème, pas vermillon — la frame ; le vermillon est réservé au futur, écran 13).
    - Rang : `.fudoFont(.label(12, weight: .semibold))`, `.kerning(2.5)`, `textSecondary`.
  - Titre : `.fudoFont(.title(28, weight: .bold))`, `padding(.top, 40)`.
  - Corps : `.fudoFont(.body(15))`, `textSecondary`, `.lineSpacing(3)`, `padding(.top, 22)`.
  - ⚠️ **`Rank` n'a pas de `displayName`** (constat de la session Progression, qui a créé un helper LOCAL). Progression a le sien ; l'onboarding en a besoin aussi → **deux helpers locaux = une divergence qui arrive**. Reco : ce plan crée `Rank.displayName` dans `Core/Models/SharedTypes.swift` (une ligne, EN, source unique) et **Progression bascule dessus** (suppression de son helper local). C'est un ajout, pas un refactor de comportement — mais il touche Core : **demander l'accord de Romain avant d'exécuter cette étape** (règle "avant de refactorer, demander confirmation").
    ```swift
    extension Rank {
        /// EN display name — the ONE source (Progression and the onboarding both read it).
        var displayName: String {
            switch self {
            case .novice: "Novice"
            case .disciple: "Disciple"
            case .ascetic: "Ascetic"
            case .warrior: "Warrior"
            case .master: "Master"
            case .sensei: "Sensei"
            }
        }
    }
    ```
- **Animations :** le paysan arrive en fade + `scaleEffect` 0.97 → 1 (`AppAnimation.slow`) ; le nombre fait un **count-up sobre 0 → 43** (`countUpDuration`, réutilise `CountUpText` d'OB 06 en mode entier) avec `Haptics.medium()` à l'arrivée ; le rang apparaît juste après (0.15 s). Le titre et le corps entrent à 0.6 s.
- **Transition → OB 11 :** slide + fade.
- **État écrit :** aucun (le `PlayerState` n'est PAS créé ici — checkpoint 1 = la signature, OB 17).

- [ ] **Step 1 : DEMANDER À ROMAIN** l'ajout de `Rank.displayName` en Core + la bascule de Progression. Si refus → helper local à l'onboarding, et loguer la divergence.
- [ ] **Step 2 : Écrire `DiagnosticScreen.swift` + câbler**
- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 10 — the diagnostic OVR"
```

- [ ] **Step 5 : GATE ROMAIN — validation simulateur de l'Acte 1**

Ce que Romain vérifie : le quiz s'enchaîne sans blocage · le CTA est bien mort tant qu'on n'a pas répondu · **le chiffre du choc correspond à ses propres réponses** (table des 16) · la recoupe parle bien de SA douleur · la reflection lui rend ses mots · l'OVR diagnostic est cohérent avec le barème (D1 : c'est le plancher).

---

# ACTE 2 — Climax (OB 11 → OB 15)

**Livrable :** il compose SON protocole, voit sa trajectoire datée, fait son premier hold, et reçoit le prompt Apple natif au pic. **Dépend de D3 et D4.**

---

### Task 11 : OB 11 — composer le protocole

**Files:**
- Create: `FUDO/Features/Onboarding/Views/ComposeProtocolScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

**Interfaces:**
- Consumes: `ChallengeSetupViewModel` (existant, **non modifié**), `DurationChip`, `RuleRowEditor`, `AddRuleRow`, `RuleEditSheet`, `PresetCatalog` (tous existants) ; `viewModel.setup` (Task 5).

> **La règle de cette tâche : zéro duplication.** `ChallengeSetupStandaloneView` est le 3e skin du MÊME view model (cf. son en-tête : "full flow, onboarding inline, standalone cover"). L'écran d'onboarding est le 4e skin — il ne réimplémente NI la sélection de preset, NI les règles, NI la validation. Si une logique manque, elle va dans `ChallengeSetupViewModel`, jamais dans l'écran.

- **Purpose :** Le basculement psychologique de tout le tunnel. Jusqu'ici l'app parlait ; ici **c'est lui qui construit**. Un protocole qu'on a écrit soi-même est un protocole qu'on n'abandonne pas — c'est le début du coût irrécupérable qui culminera sur la signature.
- **Copy (verbatim) :**
  - Eyebrow : `YOUR PROTOCOL`
  - Titre : `Your Monk Mode.\nYour rules.`
  - Chips : `30 d` · `60 d` · `75 d` · `90 d` (via `PresetCatalog.chipDays`)
  - Ligne preset : `\(PresetCatalog.title(for:days:).uppercased()) · RECOMMENDED FOR YOU` → **`MONK MODE 30 · RECOMMENDED FOR YOU`** (divergence #2 : la frame dit "CLASSIC", c'est un mock)
  - Hint : `Tap a rule to adjust it. This is YOUR protocol.`
  - CTA : `Lock my protocol`
- **UI / layout :**
  - Barre 10/15, chevron ✓.
  - `chipsRow` → `DurationChip` existant, `viewModel.setup.selectDuration(days:)`.
  - `presetLine` → **exactement la logique de `ChallengeSetupStandaloneView.presetLine`** : `FudoColor.positive` (vert) si `definition.preset == recommendedPreset`, sinon `textSecondary` + le tagline. C'est l'exception verte actée.
  - `rulesList` → `RuleRowEditor` + `AddRuleRow`, `sheet` `RuleEditSheet` (`.presentationDetents([.medium])`).
  - `showRuleCountWarning` → `More rules = more failure.` en `FudoColor.negative` (déjà dans le VM).
  - Hint `.fudoFont(.caption())`, `textSecondary`.
  - CTA : **PAS de hold ici.** `ChallengeSetupStandaloneView` utilise un hold parce qu'il LANCE le défi ; ici le CTA ne fait qu'avancer vers le loader (le défi est créé à OB 19). Un tap simple. Le hold de ce tunnel, c'est la signature.
  - ⚠️ Le contenu est scrollable (5-8 règles + chips) → `ScrollView` + CTA en `.safeAreaInset(edge: .bottom)` avec le fond `bgPrimary.opacity(0.94)`, comme le standalone.
- **Animations :** entrée en cascade (chips 0 s, ligne preset 0.1 s, règles 0.15 s + 0.04/index) ; changement de chip → les règles se rechargent (`AppAnimation.standard` sur la liste, `Haptics.light()` porté par `DurationChip`). ⚠️ **Rappel du comportement acté** : changer de chip RECHARGE les défauts du preset et JETTE les édits (sémantique chips, 2026-07-12) — ne pas "améliorer" ça ici.
- **Transition → OB 12 :** slide + fade. `viewModel.prepareCompose()` a déjà été appelé à l'entrée de l'écran (`.task`).
- **État écrit :** `viewModel.setup` (preset, `durationDays`, `rules`, `reminderMinutes` = 420 silencieux — pas de picker dans l'onboarding, la frame n'en a pas ; le changement se fera dans Settings).

- [ ] **Step 1 : Écrire `ComposeProtocolScreen.swift` + câbler**
- [ ] **Step 2 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3 : Commit**

```bash
git commit -am "feat(onboarding): OB 11 — compose your protocol (4th skin of ChallengeSetupViewModel)"
```

---

### Task 12 : OB 12 + OB 19 — le loader narratif (un seul composant)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/OnboardingLoaderScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

**Interfaces:**
- Produces: `OnboardingLoaderScreen(title:steps:duration:onFinished:)` — sert OB 12 **et** OB 19.

> **Le loading EST le beat.** Aucun spinner. Il n'y a rien à charger (l'app est 100 % locale) : ce que l'écran fait vraiment, c'est donner du poids aux chiffres en les faisant "calculer". Les étapes sont narratives et nommées avec SES données.

- **Purpose (OB 12) :** Faire atterrir le fait que le protocole est *calibré sur lui*. Les 4 lignes reprennent ce qu'il vient de donner (son point faible, ses règles, son OVR, sa durée). Il attend 4 secondes et il y croit plus qu'après 4 écrans d'explications.
- **Copy OB 12 (verbatim, 2 dérivées) :**
  - Titre : `Building your protocol…`
  - Étapes : `Reading your weak spot` · `Calibrating your daily rules` · `Setting your start — OVR \(viewModel.diagnosticOVR)` · `Projecting your \(viewModel.setup.durationDays)-day climb`
  - Footer : `Locking in your numbers. A few seconds.`
- **Copy OB 19 :** cf. Task 20.
- **UI / layout :**
  - Fond : `bgPrimary` + wash vermillon (comme OB 06/09) — les 2 loaders sont des écrans chauds.
  - **Aucune barre de progression, aucun chevron, aucun CTA.** L'écran est une attente : il n'y a rien à faire.
  - Titre centré-gauche, `.fudoFont(.title(26, weight: .bold))`, `textPrimary`, positionné vers 38 % de la hauteur.
  - Étapes : `VStack(alignment: .leading, spacing: 16)`, chaque ligne = `HStack(spacing: 14)` :
    - Pastille : `Circle()` 14 pt — **faite** → `.fill(FudoColor.accent)` ; **à venir** → `.strokeBorder(FudoColor.border, lineWidth: 1.5)`.
    - Texte : `.fudoFont(.body(15, weight: .medium))` — faite → `textPrimary` ; à venir → `textSecondary.opacity(0.6)`.
  - Footer : `.fudoFont(.caption(13))`, `textSecondary.opacity(0.7)`, bas d'écran.
- **Animations :**
  - Les étapes s'allument une par une, intervalle = `duration / steps.count` (OB 12 : 4.4/4 = 1.1 s ; OB 19 : 7/4 = 1.75 s). Chaque allumage : `AppAnimation.standard` sur la pastille + la couleur du texte.
  - **Aucun haptique par étape** (règle : haptiques sur les transitions et les validations, nulle part ailleurs).
  - Auto-avance à la fin : `onFinished()` → `viewModel.advance()`.
  - ⚠️ **Idempotence** : la boucle vit dans un `.task { }` (annulé automatiquement si la view disparaît). Si l'app est backgroundée en plein loader et revient, la `.task` a été relancée → l'écran rejoue depuis le début. Acceptable (rien n'est engagé). **Mais pour OB 19, le travail réel (`commitChallenge`) DOIT être exactly-once** → il est gardé par `flags.contract != nil` + `store.activeChallenge == nil` dans `commitChallenge()` (déjà le cas : `startChallenge` refuse si un défi est actif). À vérifier explicitement en Task 20.
- **Transition → OB 13 :** slide + fade (l'auto-avance passe par `viewModel.advance()`, donc `Haptics.light()` est porté).
- **État écrit :** OB 12 → aucun. OB 19 → cf. Task 20.

- [ ] **Step 1 : Écrire `OnboardingLoaderScreen.swift` + câbler OB 12**
- [ ] **Step 2 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3 : Commit**

```bash
git commit -am "feat(onboarding): OB 12 — the narrative loader"
```

---

### Task 13 : OB 13 — la projection (split OVR, beat 2)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/ProjectionCurveView.swift`
- Create: `FUDO/Features/Onboarding/Views/ProjectionScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

**Interfaces:**
- Consumes: `OVREngine.project(from:days:)`, `Rank.from(ovr:)`, `OVREngine.displayedOVR(_:)`, `OnboardingCopy.longDate(_:)`, `viewModel.setup.endDate`.
- Produces: `ProjectionCurveView(base: Double, days: Int)`.

> **La courbe est CALCULÉE, jamais dessinée.** `DATA-MODEL §3b` : « L'écran de projection d'onboarding DOIT appeler `OVREngine.project(from:days:)` — jamais une courbe dessinée à la main. » Les 31 points viennent du moteur, un par jour.

```swift
/// The climb, day by day, straight from the engine — 0…days perfect days.
/// Nothing here decides anything: it plots what OVREngine already knows.
private var points: [(day: Int, ovr: Double)] {
    (0...days).map { ($0, OVREngine.project(from: base, days: $0)) }
}
```

- **Purpose :** Le futur devient une DATE. Pas "tu progresseras" : "le 10 août, tu seras à ~78". Un nombre exact + un jour exact = une promesse vérifiable, l'exact opposé d'une citation de motivation — et la micro-ligne le dit tout haut.
- **Copy (verbatim, tout dérivé) :**
  - Eyebrow : `YOUR TRAJECTORY`
  - Étiquette départ : `\(viewModel.diagnosticOVR) · today` → ex. `43 · today`
  - Étiquette arrivée : `~\(OVREngine.displayedOVR(projectedOVR)) · \(projectedRank.displayName.uppercased())` → ex. **`~78 · WARRIOR`** (divergence #1 : la frame dit MASTER, c'est faux — 78 est Warrior)
  - Titre : `On \(OnboardingCopy.longDate(projectionDate)), you will be\nat ~\(displayed).` → ex. `On August 10, you will be\nat ~78.`
  - Micro-ligne : `Exact date. Real number. No motivation quotes.`
  - CTA : `Continue`
- **UI / layout :**
  - Barre 11/15, chevron ✓.
  - **Carte courbe** (`bgCard`, `radiusCard` 24, bordure `border` 1 pt, hauteur ~180, `cardPadding` 16) :
    - `Chart` (Swift Charts) : un `LineMark` **vermillon** (`FudoColor.accent`, `StrokeStyle(lineWidth: 3, lineCap: .round)`, `.interpolationMethod(.monotone)`) sur les 31 points.
    - `PointMark` de départ : `FudoColor.textSecondary`, `symbolSize(60)`.
    - `PointMark` d'arrivée : `FudoColor.accent`, `symbolSize(110)`.
    - `.chartXAxis(.hidden)`, `.chartYAxis(.hidden)`, **aucune sélection tactile** (ce n'est pas la courbe de Progression : rien à explorer, c'est une promesse).
    - ⚠️ **Ne PAS réutiliser `OVRCurveView`** : elle est verte/rouge (historique, deltas réels, popover). Ici tout est vermillon (une projection n'a pas de jour raté) et rien n'est tappable. Deux sémantiques, deux composants — c'est voulu, pas de la duplication.
    - Étiquette d'arrivée en haut-droite de la carte : `.fudoFont(.stat(13))`, `FudoColor.accent`. Étiquette de départ en bas-gauche : `.fudoFont(.caption(12))`, `textSecondary`.
  - Titre : `.fudoFont(.title(28, weight: .bold))`, `padding(.top, 40)`.
  - Micro-ligne : `.fudoFont(.body(15))`, `textSecondary`, `padding(.top, 18)`.
- **Animations :** la courbe se **trace** de gauche à droite en 0.6 s (`AppAnimation.slow`) — implémentation : `.chartXScale(domain: 0...days)` fixe + un `@State private var drawn: Int` qui passe de 0 à `days` (les points affichés = `points.prefix(drawn)`), animé. Le point d'arrivée + son étiquette apparaissent à la fin, avec `Haptics.medium()`. Le titre et la micro-ligne entrent à 0.8 s / 1.0 s.
- **Transition → OB 14 :** slide + fade.
- **État écrit :** aucun.

- [ ] **Step 1 : Écrire `ProjectionCurveView.swift`**
- [ ] **Step 2 : Écrire `ProjectionScreen.swift` + câbler**
- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 13 — the dated projection, curve straight from OVREngine"
```

---

### Task 14 : OB 14 — le premier hold-to-check (+ `ringWidth` sur `HoldToConfirm`)

**Files:**
- Modify: `FUDO/Core/DesignSystem/HoldToConfirm.swift`
- Create: `FUDO/Features/Onboarding/Views/FirstCheckScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

**Interfaces:**
- Consumes: `HoldToConfirm` / `.holdToConfirm(in:duration:completionHaptic:ringColor:onConfirm:)`, `ParticleBurstView`, `FudoGradient.flame`.
- Produces: paramètre `ringWidth` sur `HoldToConfirm` et sur le modifier `.holdToConfirm(...)`.

- [ ] **Step 1 : Ajouter `ringWidth` à `HoldToConfirm`**

Le composant fixe son trait à `HoldToConfirmMetrics.ringWidth` (3 pt) — calibré pour un anneau qui longe une card de 56 pt. L'anneau HOLD d'OB 14 fait 148 pt de diamètre : 3 pt y sont invisibles. Même pattern que l'ajout de `ringColor` (2026-07-13) : un paramètre avec défaut, zéro call site touché.

```swift
struct HoldToConfirm<Ring: InsettableShape>: ViewModifier {
    let shape: Ring
    let duration: TimeInterval
    let completionHaptic: HoldCompletionHaptic
    var ringColor: Color = FudoColor.accent
    /// Stroke width — the card rings keep the 3 pt default; the onboarding's
    /// 148 pt HOLD circle passes a thicker one (3 pt vanishes at that diameter).
    var ringWidth: CGFloat = HoldToConfirmMetrics.ringWidth
    let onConfirm: () -> Void
    ...
    private var ring: some View {
        shape
            .inset(by: ringWidth / 2)
            .trim(from: 0, to: progress)
            .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            .opacity(ringOpacity)
            .allowsHitTesting(false)
    }
}
```
Et sur le modifier :
```swift
func holdToConfirm(
    in shape: some InsettableShape = RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous),
    duration: TimeInterval = HoldToConfirmMetrics.duration,
    completionHaptic: HoldCompletionHaptic = .success,
    ringColor: Color = FudoColor.accent,
    ringWidth: CGFloat = HoldToConfirmMetrics.ringWidth,
    onConfirm: @escaping () -> Void
) -> some View {
    modifier(HoldToConfirm(shape: shape, duration: duration, completionHaptic: completionHaptic,
                           ringColor: ringColor, ringWidth: ringWidth, onConfirm: onConfirm))
}
```
⚠️ La docstring du modifier dit encore "1.5 s" alors que `HoldToConfirmMetrics.duration` vaut 1.0 → corriger le commentaire au passage (`defaults match the checklist card: card-radius ring, 1 s, success haptic`).

- [ ] **Step 2 : Compile-only pour vérifier qu'aucun call site n'a bougé**

Run: `xcodebuild build -scheme FUDO -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED (les 3 call sites existants — checklist, CTA setup ×2 — compilent inchangés).

- [ ] **Step 3 : Écrire `FirstCheckScreen.swift`**

- **Purpose :** Il **fait** le geste. C'est le seul écran du tunnel où sa main apprend quelque chose : la tenue de 1 seconde, l'anneau qui se remplit, l'haptique qui monte, le sceau. Et son premier check n'est pas une tâche : c'est *"j'ai commencé"*. La flamme s'allume — la streak existe avant même le jour 1.
- **Copy (verbatim) :**
  - Eyebrow : `FIRST ACTION`
  - Titre : `Validate your first action.`
  - Carte : `"I started my Monk Mode."` (guillemets inclus) + `Your first check. It counts.`
  - Anneau : `HOLD`
  - Hint : `Hold to check.` (divergence #4 : la frame dit "Hold for 1.5 seconds" ; la constante vaut 1.0 → **aucun nombre dans la copy**, elle ne peut plus dériver)
  - Flamme (après le sceau) : `Day 0 — streak ignited`
- **UI / layout :**
  - **Barre 12/15, PAS de chevron** (on ne revient pas d'un geste qu'on a fait).
  - Fond : `bgPrimary` + wash vermillon bas (`RadialGradient` centré sur l'anneau, `accentDeep.opacity(0.30) → .clear`) — la frame chauffe autour du HOLD.
  - Carte (sous le titre, `padding(.top, 28)`) : `RoundedRectangle(radiusCard)`, fill `bgCard`, **bordure `FudoColor.accent.opacity(0.55)` 1 pt** (la frame la souligne en vermillon — c'est la phrase qui compte), `cardPaddingMajor` 20.
    - Citation : `.fudoFont(.headline(17))`, `textPrimary`.
    - Sous-ligne : `.fudoFont(.caption(13))`, `textSecondary`, `padding(.top, 6)`.
  - **L'anneau HOLD**, centré, `padding(.top, 56)` :
    - Track : `Circle().strokeBorder(FudoColor.border, lineWidth: OnboardingMetrics.firstCheckRingWidth)`, diamètre `OnboardingMetrics.firstCheckRingDiameter` (148).
    - Label : `HOLD`, `.fudoFont(.label(15, weight: .bold))`, `.kerning(4)`, `textPrimary`.
    - Le geste : `.holdToConfirm(in: Circle(), completionHaptic: .success, ringColor: FudoColor.accent, ringWidth: OnboardingMetrics.firstCheckRingWidth) { seal() }` sur le `ZStack` de l'anneau (`.frame(width: 148, height: 148).contentShape(Circle())`).
    - ⚠️ `HoldToConfirm` insets de `ringWidth/2` : le track et l'anneau de progression doivent se superposer exactement → le track utilise `.strokeBorder` (inset intérieur) et la même largeur. À vérifier à l'œil sur device.
  - Hint sous l'anneau : `.fudoFont(.caption(13))`, `textSecondary`, `padding(.top, 20)`.
  - Flamme : `Label("Day 0 — streak ignited", systemImage: "flame.fill")` — le symbole en `.foregroundStyle(FudoGradient.flame)`, le texte en `FudoColor.celebrationGold`, `.fudoFont(.stat(15))`. **Masquée jusqu'au sceau.**
- **Animations :**
  - Entrée : titre + carte en cascade ; l'anneau à 0.3 s (fade + scale 0.96 → 1).
  - **Respiration d'invite** : le label `HOLD` et le track pulsent très légèrement (opacité 0.75 ↔ 1, `hintPulse` 1.8 s) tant qu'on n'a pas tenu — il doit comprendre sans lire.
  - **Au sceau** (`onConfirm`) :
    1. `HoldToConfirm` tire `Haptics.success()` et fait disparaître son anneau (`sealResetDelay` 0.6 s) ;
    2. `ParticleBurstView(colors: [FudoColor.accent], particleCount: ParticleBurstMetrics.checkCount, originRadius: 74)` — le burst part **de l'anneau**, comme sur le Home (`.id(sealTrigger)` pour rejouer) ;
    3. le label passe de `HOLD` à un `checkmark` crème (`AppAnimation.standard`) ;
    4. la flamme apparaît à 0.45 s : fade + montée 10 pt + `Haptics.medium()`.
  - **Auto-avance** à `OnboardingMetrics.firstCheckSettle` (1.4 s) après le sceau → `viewModel.advance()`. **Aucun CTA** (la frame n'en a pas : le geste EST le CTA).
  - **Exactly-once** : `HoldToConfirm` garantit déjà un seul `onConfirm` par tenue (`sealed`), mais l'écran ajoute son propre `@State private var hasSealed = false` — un `guard !hasSealed` — parce que le composant se réarme après 0.6 s et qu'une deuxième tenue pendant l'attente d'auto-avance déclencherait un 2e `advance()`.
- **Transition → OB 15 :** slide + fade.
- **État écrit :** **AUCUN.** ⚠️ C'est une **démo** : le défi n'existe pas encore (créé à OB 19), `store.checkTask` n'est PAS appelé, l'OVR ne bouge pas, aucune streak n'est écrite. La flamme "Day 0" est purement visuelle — la vraie streak démarrera à la première journée 100 % close. Le documenter en tête de fichier : un futur lecteur voudra "brancher le vrai check" et casserait l'anti-farming.

- [ ] **Step 4 : Câbler le `switch`**
- [ ] **Step 5 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 6 : Commit**

```bash
git add FUDO/Core/DesignSystem/HoldToConfirm.swift FUDO/Features/Onboarding
git commit -m "feat(onboarding): OB 14 — the first hold-to-check demo, HoldToConfirm gains ringWidth"
```

---

### Task 15 : OB 15 — preuve sociale + prompt de review natif

**Files:**
- Create: `FUDO/Features/Onboarding/Views/SocialProofScreen.swift`
- Modify: `FUDO/Features/Onboarding/OnboardingFlags.swift` (flag `reviewPrompted`)
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

> ✅ **D4 tranchée (non-chiffré tout de suite)** : **la note "4.8 on the App Store" et les 5 étoiles ne sont PAS construites.** Une note qu'on n'a pas gagnée est une fausse mesure, et des étoiles sans note en sont une aussi (elles affirment exactement la même chose). L'écran s'appuie sur les témoignages seuls — dont les placeholders sont marqués pour remplacement pré-submit (§ point ouvert).

- **Purpose :** Au pic exact — il vient de faire son premier geste, la flamme est allumée — on lui montre qu'il n'est pas seul, et on demande la note. Le prompt Apple tombe sur l'émotion la plus haute du tunnel : c'est le seul moment où un 5 étoiles est sincère.
- **Copy (verbatim) :**
  - Eyebrow : `YOU ARE NOT ALONE`
  - Titre : `SocialProofCopy.proofTitle` → `Men like you,\nlocked in.`
  - **Aucune ligne de note, aucune étoile** (D4).
  - Témoignages : `SocialProofCopy.testimonials` — placeholders marqués, à remplacer par de vrais retours de testeurs avec leur accord avant soumission.
  - CTA : `Continue`
- **UI / layout :**
  - **Barre 13/15, pas de chevron.**
  - Le titre est suivi directement des cartes (`padding(.top, 32)`) — l'espace des étoiles/de la note est simplement rendu au blanc, pas comblé.
  - 3 cartes (`bgCard`, `radiusCard`, bordure `border`, `cardPadding` 16, spacing 12) : citation `.fudoFont(.body(15))` `textPrimary` ; attribution `.fudoFont(.caption(12))` `textSecondary`, `padding(.top, 8)`.
- **Le prompt natif — implémentation réelle (absent de RiteOff, à faire ici) :**
```swift
@Environment(\.requestReview) private var requestReview

.task {
    // The peak: he just lit his streak. Native prompt ONLY — never a custom
    // rate-us modal (known-pitfalls list). iOS rate-limits it on its own; the
    // flag keeps US from asking twice in one install.
    guard !flags.reviewPrompted else { return }
    try? await Task.sleep(for: .seconds(OnboardingMetrics.reviewPromptDelay))
    flags.reviewPrompted = true
    requestReview()
}
```
  - Ajouter `OnboardingMetrics.reviewPromptDelay: TimeInterval = 0.8` (le temps que l'écran se pose — le prompt ne doit pas cannibaliser l'entrée).
  - Ajouter `OnboardingFlags.reviewPrompted` (clé `"onboarding.reviewPrompted"`), **non effacé par `reset()`** : rejouer l'onboarding en DEBUG ne doit pas re-solliciter. → une clé à part, en dehors du `removePersistentDomain`.
  - ⚠️ `@Environment(\.requestReview)` est iOS 16+, OK sur iOS 17. En simulateur, la feuille système ne s'affiche pas toujours — **normal**, ne pas "réparer".
- **Animations :** cartes en cascade (0.08 s/index, fade + montée 10 pt). Le prompt système arrive par-dessus à 0.8 s.
- **Transition → OB 16 :** slide + fade.
- **État écrit :** `flags.reviewPrompted = true`.

- [ ] **Step 1 : Ajouter `reviewPrompted` (hors `reset()`) + `reviewPromptDelay`**
- [ ] **Step 2 : Écrire `SocialProofScreen.swift` (+ `SocialProofCopy` isolé) + câbler**
- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 15 — social proof and the native review prompt at the peak"
```

- [ ] **Step 5 : GATE ROMAIN — validation simulateur de l'Acte 2**

Ce que Romain vérifie : composer/éditer les règles marche comme le standalone · le loader ne traîne pas · **la date de projection est exacte** (aujourd'hui + durée − 1) · le rang affiché est WARRIOR et pas Master · **le feel du hold** sur device (anneau 148, trait 7) · la flamme day-0 · le prompt de review apparaît (device de préférence).

---

# ACTE 3 — Engagement, contrat, paywall (OB 16 → OB 17 → gate)

**Livrable :** la dernière question, le contrat signé au doigt, le checkpoint kill-safety, et la sortie vers un stub de paywall. **Dépend de D1 et D7.**

---

### Task 16 : OB 16 — l'engagement

**Files:**
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift` (réutilise `SingleChoiceScreen`)

- **Purpose :** La dernière question est un serment déguisé. Il n'y a pas de mauvaise réponse — "A little" est accueilli, pas puni ("Then start small. 30 days.") — donc il répond vrai. Et sa réponse **vaut des points** : c'est la seule question du tunnel qui paie (D1).
- **Copy (verbatim) :**
  - Eyebrow : `LAST QUESTION`
  - Titre : `How committed\nare you, really?`
  - Options : `Extremely — start today` · `Very — I want this` · `A little — testing the waters`
  - Hint (sous les options) : `"A little"? Then start small. 30 days.`
  - CTA : `Continue`
- **UI :** `SingleChoiceScreen` + un `hint` optionnel (ajouter le paramètre au composant : `hint: String?`, rendu sous les rows, `.fudoFont(.caption(13))`, `textSecondary`). **Barre 14/15, pas de chevron.**
  - Ordre = frame : `[.extremely, .very, .somewhat]` (identique à `allCases` ✓).
  - Libellés via une extension côté onboarding (comme les autres) :
    ```swift
    extension OnboardingAnswers.Commitment {
        var optionTitle: String {
            switch self {
            case .extremely: "Extremely — start today"
            case .very: "Very — I want this"
            case .somewhat: "A little — testing the waters"
            }
        }
    }
    ```
- **Animations :** cascade standard. **D1 — le beat du bonus** : à la sélection, si `points > 0`, un `+\(points) OVR` flottant apparaît brièvement à droite de la row (fade + montée 14 pt, disparition en 1.2 s), `FudoColor.positive` pour la flèche `arrowtriangle.up.fill` et `textPrimary` pour le texte. C'est ce qui rend visible que le nombre du contrat ait monté depuis OB 10. Pour `.somewhat` (0 pt) : rien — pas de "+0", pas de punition.
- **Transition → OB 17 :** slide + fade.
- **État écrit :** `draft.commitment` → **OVR de départ** (+2/+1/+0). C'est la 4e et dernière entrée du barème `DATA-MODEL §3a`.

- [ ] **Step 1 : Ajouter `hint` à `SingleChoiceScreen` + l'extension `optionTitle`**
- [ ] **Step 2 : Câbler OB 16 + le "+N OVR" flottant**
- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 16 — the commitment question and its OVR bonus"
```

---

### Task 17 : OB 17 — le contrat signé (checkpoint kill-safety 1)

**Files:**
- Create: `FUDO/Features/Onboarding/Views/SignatureCanvas.swift`
- Create: `FUDO/Features/Onboarding/Views/ContractScreen.swift`
- Create: `FUDO/Features/Onboarding/PricingCopy.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

- **Purpose :** Le coût irrécupérable, matérialisé. Il a composé son protocole, vu sa date, fait son geste — ici il **signe**, avec son doigt, sur un écran noir. Ce n'est pas une case à cocher : c'est un tracé qui lui appartient, suivi d'une tenue de 2,5 secondes. Après ça, abandonner n'est plus "ne pas commencer", c'est **se dédire**. Et le prix arrive APRÈS la signature — quand la valeur est déjà encaissée.
- **Copy (verbatim, dérivées marquées) :**
  - Eyebrow : `THE CONTRACT`
  - Carte 1 — label `WHERE YOU ARE` · valeur `OVR \(finalOVR) — \(rank.displayName)` → ex. `OVR 45 — Novice` *(dérivé : D1, l'OVR final inclut le bonus d'engagement)*
  - Carte 2 — label `WHERE YOU'RE GOING` · valeur `OVR ~\(projected) — \(projectedRank.displayName), on \(longDate)` → ex. `OVR ~79 — Warrior, on August 10` *(dérivé ; divergence #1 : pas "Master")*
  - Carte 3 — label `THE TERMS` · valeur `Daily check-in · No zero days · \(durationDays) days` → ex. `Daily check-in · No zero days · 30 days`
  - Carte signature — label `I COMMIT TO THE PROTOCOL` · pied `Signed · today`
  - Accroche prix : `Less than a kebab per month.`
  - Détail prix : `3-day free trial, then $5.99/week or $43.99/year.\nCancel anytime.` *(⚠️ D7 : constantes `PricingCopy`, remplacées par les vrais `StoreProduct` RevenueCat en S6)*
  - CTA : `HOLD TO SIGN`
- **UI / layout :**
  - **Barre 15/15 (pleine), pas de chevron.** C'est le bout du tunnel de persuasion.
  - 3 cartes récap (spacing 10) : `bgCard`, `radiusCard`, bordure `border`, `cardPadding` 16.
    - Label : `.fudoFont(.label(11, weight: .semibold))`, `.kerning(1.5)`, `textSecondary`.
    - Valeur : `.fudoFont(.headline(17))`, `padding(.top, 6)` — **carte 1 en `textPrimary`, carte 2 en `FudoColor.accent`** (le futur est vermillon, le présent est crème : la même grammaire qu'OB 10 vs OB 13), carte 3 en `textPrimary`.
  - **Carte signature** (`padding(.top, 14)`, hauteur ~130) : même fond, avec :
    - Label `I COMMIT TO THE PROTOCOL` en haut.
    - `SignatureCanvas` au centre (hauteur 62).
    - Une ligne de base : `Rectangle().fill(FudoColor.border).frame(height: 1)`.
    - `Signed · today` : `.fudoFont(.caption(12))`, `textSecondary`, **visible seulement une fois le tracé posé** (fade `AppAnimation.standard`).
  - Accroche prix : `.fudoFont(.title(24, weight: .bold))`, `textPrimary`, `padding(.top, 26)`.
  - Détail prix : `.fudoFont(.caption(13))`, `textSecondary`, `.lineSpacing(2)`, `padding(.top, 8)`.
  - CTA : Capsule `accent`, `.fudoFont(.headline())`, `.kerning(1)`, texte `textPrimary` — **hold** : `.holdToConfirm(in: Capsule(), duration: OnboardingMetrics.signHoldDuration, completionHaptic: .heavy, ringColor: FudoColor.textPrimary) { viewModel.signContract() }`, `.disabled(!viewModel.hasSignature)`.
  - ⚠️ Contenu long (3 cartes + signature + prix) → `ScrollView` + CTA en `.safeAreaInset(edge: .bottom)`. **Piège** : `HoldToConfirm` est bâti sur un `Button` justement pour que le scroll gagne — dans un `safeAreaInset`, le CTA n'est pas dans le scroll, donc aucun conflit. Le `SignatureCanvas`, lui, EST dans le scroll : son `DragGesture` va se battre avec le scroll vertical → **il faut `.simultaneousGesture` non, l'inverse** : le canvas doit gagner. Reco : `DragGesture(minimumDistance: 0)` sur le canvas + `.scrollDisabled(isDrawing)` sur le `ScrollView` (`isDrawing` remonté par le canvas via un binding). C'est le point le plus délicat de l'écran — à vérifier sur device.

**`SignatureCanvas` — spec :**
```swift
/// A finger signature on a dark card: raw points captured by a drag, drawn as a
/// smoothed path. Not a drawing tool — no colors, no undo, no clear button
/// (frame 17): a signature is whatever his hand does, once.
struct SignatureCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @Binding var isDrawing: Bool
    ...
}
```
- Capture : `DragGesture(minimumDistance: 0)` → `onChanged` ajoute le point au trait courant + `isDrawing = true` ; `onEnded` ferme le trait + `isDrawing = false` + notifie `viewModel.registerSignature()`.
- Rendu : un `Path` par trait, points reliés par des **courbes quadratiques sur les milieux** (`addQuadCurve(to: mid, control: previous)`) → un trait fluide, pas une ligne brisée. `.stroke(FudoColor.textPrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))`.
- ⚠️ **Performance** : un `Path` reconstruit à chaque point sur 300+ points rame. Reco : `Canvas { context, size in ... }` (dessin immédiat, pas d'arbre de views).
- Aucun stockage : les traits vivent en `@State` de l'écran et **meurent avec lui**. On ne persiste PAS l'image de la signature (aucune valeur légale, aucune utilité produit, et ce serait une donnée personnelle à protéger pour rien).

- **Animations :** les 3 cartes entrent en cascade (0.06 s/index) ; la carte signature à 0.3 s ; le bloc prix à 0.5 s. Le tracé apparaît sous le doigt, sans animation (c'est direct, c'est le point). `Signed · today` fade à la fin du premier trait. Le CTA passe de grisé à vermillon (`AppAnimation.standard`) quand `hasSignature` bascule. Au sceau : `Haptics.heavy()` (porté par `HoldToConfirm`), l'anneau crème se ferme sur la capsule, puis transition.
- **Transition → paywall :** `signContract()` avance après avoir écrit le checkpoint. Laisser le sceau atterrir : `Task.sleep(HoldToConfirmMetrics.sealResetDelay)` avant `advance()` — **exactement le pattern de `ChallengeSetupStandaloneView.start()`**.
- **État écrit — CHECKPOINT 1 :**
  - `GameStore.ensurePlayer(startingOVR:)` → le `PlayerState` existe, l'OVR est réel et survit à un kill.
  - `flags.contract = ContractSnapshot(...)` → le protocole composé est sérialisé.
  - **PAS de `Challenge`** (cf. la section kill-safety : son horloge ne doit pas tourner derrière le paywall).

- [ ] **Step 1 : Écrire `PricingCopy.swift`**
```swift
/// Session 5 stubs. Session 6 replaces every value with the RevenueCat
/// StoreProduct's localized price — Apple requires the real price and the
/// auto-renew mention on screen (known-pitfalls list). Never ship these as-is.
enum PricingCopy {
    static let hook = "Less than a kebab per month."
    static let detail = "3-day free trial, then $5.99/week or $43.99/year.\nCancel anytime."
}
```
- [ ] **Step 2 : Écrire `SignatureCanvas.swift`**
- [ ] **Step 3 : Écrire `ContractScreen.swift` + câbler**
- [ ] **Step 4 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 5 : Commit**

```bash
git commit -am "feat(onboarding): OB 17 — the signed contract, kill-safety checkpoint 1"
```

---

### Task 18 : Le gate paywall (stub S5)

**Files:**
- Create: `FUDO/Features/Paywall/Views/PaywallGateView.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

> **Ne PAS construire le paywall.** Il est la session 6 (RevenueCat, trial-first, loading + retry obligatoires, restore, prix réels). Cette session livre le **gate** : l'étape existe dans la machine, elle écrit le checkpoint 2, et S6 remplacera le corps de la view sans toucher au flow.

- **Purpose (du stub) :** occuper la place exacte du paywall dans la machine pour que le kill-safety, le hold-lock et la reprise soient testables MAINTENANT.
- **UI :** `PlaceholderScaffold`-like, mais **avec un vrai bouton** (jamais de bouton mort) :
  - Titre : `Paywall — Session 6`
  - Sous-titre : `Your protocol is ready. OVR \(startingOVR) → ~\(projected) by \(date).`  *(dérivé du `ContractSnapshot` : le stub prouve déjà que les données ont survécu à la signature)*
  - CTA : `Continue (stub)` → `viewModel.passPaywall()`.
  - `#if DEBUG` **non** : l'écran doit exister en Release aussi (sinon la machine casse) — c'est S6 qui le remplace. Le noter en tête de fichier.
- **Barre :** aucune (`.paywall.showsProgress == false` ✓).
- **État écrit — CHECKPOINT 2 :** `flags.hasCompletedOnboarding = true`. Le quiz ne rejouera jamais. Le **hold-lock** prend le relais : `isFullyDone` reste faux tant qu'OB 21 n'est pas passé.

- [ ] **Step 1 : Écrire `PaywallGateView.swift` + câbler**
- [ ] **Step 2 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3 : Commit**

```bash
git commit -am "feat(onboarding): paywall gate stub — checkpoint 2, Session 6 fills it in"
```

- [ ] **Step 4 : GATE ROMAIN — validation simulateur de l'Acte 3**

Ce que Romain vérifie : le "+N OVR" d'OB 16 · **le contrat affiche l'OVR final** (celui d'OB 10 + le bonus) · la signature au doigt est fluide et ne se bat pas avec le scroll · le hold 2,5 s se sent LOURD (pas comme un check) · **le kill test** : signer, tuer l'app, relancer → on repart au paywall, le protocole est intact.

---

# ACTE 4 — Post-paywall (OB 18 → OB 21)

**Livrable :** la permission de notifications avec une planification RÉELLE, le loader qui crée le défi, l'accueil au dojo, le widget promo, et la sortie vers Home day 1 — avec le hold-lock qui tient jusqu'au bout. **Dépend de D2 et D6.**

---

### Task 19 : `NotificationService` + OB 18

**Files:**
- Create: `FUDO/Core/Services/NotificationService.swift`
- Create: `FUDO/Features/Onboarding/Views/NotificationsScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

> ⚠️ **Le bug RiteOff à ne pas répéter** : leurs écrans de permission appelaient des stubs no-op — l'user accordait la permission et ne recevait jamais rien. Ici, "Allow" **planifie réellement**, et la Task se termine par une vérification device.

**`NotificationService` — spec :**
```swift
import UNUserNotifications

/// Local notifications only — zero push, zero server (CLAUDE.md). This session
/// wires ONE notification: the daily reminder. The conditional set (evening,
/// streak in danger, trial D-1, decay, rank-up, 2/day cap) is a later session;
/// it will live behind this same service.
@MainActor
enum NotificationService {
    static let dailyReminderID = "fudo.daily.reminder"

    /// Returns what the user chose. Never throws at the caller: a denied
    /// permission is a normal path, not an error.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// The one reminder that ships in S5. Repeats daily at the challenge's
    /// reminder hour. Replacing the request with the same identifier is how you
    /// reschedule — never accumulate duplicates.
    static func scheduleDailyReminder(atMinutes minutes: Int) async {
        cancelDailyReminder()
        let content = UNMutableNotificationContent()
        content.title = "FUDO"
        // No day number: a repeating trigger has static content, and a stale
        // "Day 12" would be a lie by day 13. The conditional session will swap
        // this for per-day scheduled content.
        content.body = "Your protocol is waiting."
        content.sound = .default

        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
```
⚠️ Aucune clé `Info.plist` n'est requise pour les notifications locales. Aucun `PrivacyInfo.xcprivacy` non plus (c'est une API système, pas un SDK tiers) — ça, c'est pour RevenueCat/PostHog, sessions ultérieures.

---

#### OB 18 — NOTIFICATIONS

- **Purpose :** La permission demandée **après** le paywall, quand il est déjà engagé — et **précédée** d'un écran à nous qui explique ce qu'il perd en refusant. La popup iOS ne se présente jamais nue : on l'a préparée. C'est le levier de rétention n°2 (le widget est le n°1).
- **Copy (verbatim, 1 dérivée) :**
  - Titre : `Your daily reminder\nat \(OnboardingCopy.clockTime(minutes: reminderMinutes)).` → ex. `Your daily reminder\nat 7:00 AM.` *(divergence #5 : la frame dit 6:30, c'est un mock)*
  - Ligne vermillon : `SocialProofCopy.reminderStake` → **`Without it, most men are done by day 4.`** (D4 : la frame disait "you are statistically dead by day 4" — "statistically" promettait une mesure qui n'existe pas ; la claque reste, la fausse mesure part.)
  - Aperçu notif : `FUDO` / `Day 12. Your protocol is waiting. 🔥11` → **recut** : `FUDO` / `Day 1. Your protocol is waiting.` + une flamme SF Symbol (divergence #3 : pas d'emoji ; #6 : "Day 12" sur un user au jour 1 sonne faux — l'aperçu montre SA première notif).
  - Sous-ligne : `iOS will ask for permission next.`
  - CTA : `Enable my reminder`
  - CTA secondaire (refus uniquement) : `Continue`
- **UI / layout :**
  - **Aucune barre** (D6 : la frame la montre pleine, la règle dit cachée — on suit la règle). Pas de chevron.
  - Cloche : `Image(systemName: "bell")`, `.fudoFont(.glyph(40, weight: .light))`, `FudoColor.accent`, alignée à gauche (frame).
  - Titre : `.fudoFont(.title(28, weight: .bold))`, `padding(.top, 28)`.
  - Ligne vermillon : `.fudoFont(.body(15, weight: .medium))`, `FudoColor.accent`, `padding(.top, 16)`.
  - **Aperçu notif** (`padding(.top, 40)`) : carte `bgCard` (⚠️ pas glass : c'est une notif iOS, pas un élément FUDO), `radiusCard`, bordure `border`, `cardPadding` 16 :
    - Icône app : `RoundedRectangle(cornerRadius: 10)` `bgPrimary` 40×40 + l'ensō (`Image("enso-100")`) dedans, teinté accent.
    - Titre `FUDO` : `.fudoFont(.headline(14))`, `textPrimary`.
    - Corps : `Day 1. Your protocol is waiting.` `.fudoFont(.body(14))`, `textSecondary` + `flame.fill` en `FudoGradient.flame`.
  - Sous-ligne : `.fudoFont(.caption(13))`, `textSecondary`, `padding(.top, 16)`.
- **Le flow de permission (le cœur de la task) :**
```swift
private func requestPermission() async {
    let granted = await NotificationService.requestAuthorization()
    if granted {
        // The RiteOff bug: their "Allow" scheduled nothing. This one does.
        await NotificationService.scheduleDailyReminder(atMinutes: viewModel.reminderMinutes)
        viewModel.advance()                 // granted → auto-advance, no second tap
    } else {
        withAnimation(AppAnimation.standard) { wasDenied = true }   // → manual "Continue"
    }
}
```
  - **Accordé** → auto-avance (il a dit oui, on ne lui redemande rien).
  - **Refusé** → le CTA devient `Continue` (secondaire : Capsule `bgCard` + bordure) et une ligne discrète apparaît : `You can turn it on later in Settings.` (`.fudoFont(.caption(13))`, `textSecondary`). **Aucune insistance, aucun mur.**
  - ⚠️ **Déjà refusé au niveau système** (rejeu, ou refus antérieur) : `requestAuthorization` retourne `false` immédiatement sans afficher de popup → l'écran doit gérer ce cas exactement comme un refus (il le fait ✓). Ne PAS ouvrir les Réglages iOS d'autorité.
  - ⚠️ **Le rappel est planifié ici, avant que le `Challenge` n'existe** (créé à OB 19) — c'est volontaire : l'heure vient du `ContractSnapshot`, et le rappel n'a pas besoin du défi. Si l'user tue l'app entre 18 et 19, il aura un rappel sans défi → au premier lancement, `RootView` reprend à OB 18 (hold-lock) et le flow se termine normalement. Cas bénin, documenté.
- **Animations :** cloche en fade + scale 0.9 → 1 ; titre/ligne/carte en cascade. La carte d'aperçu **glisse du haut** (offset -16 → 0) comme une vraie notif qui tombe, `AppAnimation.slow`.
- **Transition → OB 19 :** slide + fade.
- **État écrit :** la planification système (`UNUserNotificationCenter`) + rien en local.

- [ ] **Step 1 : Écrire `NotificationService.swift`**
- [ ] **Step 2 : Écrire `NotificationsScreen.swift` + câbler**
- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): OB 18 — notifications screen with REAL daily scheduling"
```

- [ ] **Step 5 : VÉRIFICATION ROMAIN (device, obligatoire pour cette task)**

Sur iPhone : accorder la permission → **Réglages iOS > Notifications > FUDO doit être ON**, et le rappel doit tomber à l'heure. Le test rapide : régler le rappel sur "dans 2 minutes" via un build DEBUG temporaire, ou vérifier la requête en attente avec un `print` de `getPendingNotificationRequests()` en DEBUG. **Un "Allow" qui ne planifie rien = le bug qu'on répare, il doit être constaté, pas supposé.**

---

### Task 20 : OB 19 → OB 21 — loader, dojo, widget, sortie

**Files:**
- Create: `FUDO/Features/Onboarding/Views/WelcomeDojoScreen.swift`
- Create: `FUDO/Features/Onboarding/Views/WidgetPromoScreen.swift`
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift`

---

#### OB 19 — LOADER "SETTING UP" (le vrai commit)

- **Purpose :** Le dernier temps mort du tunnel — sauf qu'ici il n'est pas décoratif : c'est là que le défi naît vraiment. Les 7 secondes donnent du poids à ce qui est en train de devenir réel.
- **Copy (verbatim) :**
  - Titre : `Setting up your protocol…`
  - Étapes : `Saving your protocol` · `Scheduling your daily reminder` · `Preparing your dojo` · `Lighting your streak`
  - Footer : **`Day 1 starts today. Almost there.`** (D2 tranchée : la frame disait "Your reset starts tomorrow", le moteur force jour 1 = aujourd'hui — c'est la copy qui plie, pas le moteur.)
- **UI :** `OnboardingLoaderScreen` (Task 12), `duration: OnboardingMetrics.setupLoaderDuration` (7 s). Aucune barre, aucun chevron, aucun CTA.
- **Le travail réel :** à l'étape 1 (`Saving your protocol`, donc à t=0), l'écran appelle `viewModel.commitChallenge()`.
  - **Exactly-once** : `commitChallenge()` est gardé (`guard let contract = flags.contract`) et `GameStore.startChallenge` refuse si un défi est déjà actif. Un background/foreground qui rejoue la `.task` ne crée pas un 2e défi. **À verrouiller par un test** (déjà écrit en Task 5 : `theLoaderCommitsTheChallengeAfterThePaywall` — ajouter l'appel double) :
    ```swift
    @Test func committingTwiceCreatesOneChallenge() throws {
        // A background/foreground mid-loader replays the .task — it must not
        // start a second challenge.
        let (vm, store, _) = try makeViewModel()
        vm.draft.scrollTime = .underTwoHours
        vm.jump(to: .contract); vm.registerSignature(); vm.signContract(); vm.passPaywall()
        vm.commitChallenge()
        vm.commitChallenge()
        #expect(store.activeChallenge != nil)
        // The store's invariant: one .active at a time (GameStore.startChallenge guard).
    }
    ```
- **Transition → OB 20 :** auto-avance à 7 s.
- **État écrit :** **le `Challenge`** (preset, durée, règles, `reminderMinutes`, `startOVR`, `startDate` = aujourd'hui) + le `DayLog` du jour 1 (créé par `startChallenge` → `ensureTodayLog`).

---

#### OB 20 — WELCOME DOJO

- **Purpose :** La récompense. Plus de questions, plus de chiffres : le sensei est là, en pied, et il te dit une seule chose à faire ce soir. Le tunnel se termine par un ordre simple, tenable — pas par une liste.
- **Copy (verbatim, D2 tranchée) :**
  - Titre : `Welcome to the dojo.`
  - Corps : **`Day 1 is today. Your reminder rings tomorrow at \(OnboardingCopy.clockTime(minutes: reminderMinutes)).\nTonight: sleep. That's the first order.`** → ex. `Day 1 is today. Your reminder rings tomorrow at 7:00 AM.` (la frame disait "Your Monk Mode starts tomorrow at 6:30 AM" — contredisait le moteur ET l'heure venait d'un mock. "Tonight: sleep. That's the first order." survit : c'est la meilleure ligne de l'écran, et elle reste vraie — ce qu'il peut cocher ce soir, il le coche ; le reste se joue demain.)
  - CTA : `Let's go`
- **UI / layout :**
  - **Aucune barre, aucun chevron.**
  - Sensei plein cadre : `SenseiAssetProvider.image(for: store.player?.rank ?? .novice)` — ⚠️ la frame montre un sensei en gi blanc (rang élevé) ; le joueur réel est **Novice** (OVR 43-47). Reco : afficher **son** rang (le paysan), pas un sensei qu'il n'a pas gagné — sinon le premier écran de l'app le contredit (Home affichera le paysan). **À confirmer avec Romain au gate** (c'est un choix visuel, la frame est peut-être intentionnelle).
    - `.resizable().scaledToFit()`, `GeometryReader` + `.frame(maxHeight:)` + `.clipped()`, ancré en bas, opacité pleine.
    - Derrière : `RadialGradient(FudoColor.accent.opacity(0.28) → .clear)` — l'aura du dojo.
    - Scrim bas (`LinearGradient(.clear → bgPrimary.opacity(0.95)`) pour que le texte tienne.
  - Titre centré, `.fudoFont(.title(30, weight: .bold))`, `textPrimary`, à ~48 % de la hauteur.
  - Corps centré, `.fudoFont(.body(15))`, `textSecondary`, `.lineSpacing(3)`, `padding(.top, 12)`.
  - CTA `Let's go` en `safeAreaInset`.
- **Animations :** le sensei entre en fade + scale 0.96 → 1 (`AppAnimation.slow`) ; l'aura respire (`hintPulse`) ; le titre à 0.3 s, le corps à 0.5 s. **Pas de confetti** : la célébration est réservée aux milestones (journée 100 %, rank-up, fin de défi) — arriver au dojo n'en est pas un, c'est le début.
- **Transition → OB 21 :** slide + fade.
- **État écrit :** aucun.

---

#### OB 21 — WIDGET PROMO (la sortie)

- **Purpose :** Le dernier levier de rétention (n°1 de la liste), placé là où il ne coûte rien : il est déjà engagé, déjà servi. Trois étapes, une porte de sortie honnête ("Later"), et on le lâche dans son dojo.
- **Copy (verbatim) :**
  - Eyebrow : `ONE LAST WEAPON`
  - Titre : `Put your streak\non your home screen.`
  - Sous-ligne : `SocialProofCopy.widgetStake` → **`The widget is the difference between remembering and finishing.`** (D4 : la frame disait "Users with the widget are 2× more likely to finish" — personne n'a mesuré ce 2×.)
  - Étapes : `1. Long-press your home screen` · `2. Tap + and search "FUDO"` · `3. Add the widget`
  - Bouton secondaire : `Later`
  - CTA : `I've added it`
- **UI / layout :**
  - **Aucune barre, aucun chevron.**
  - **Mock du widget** centré (`padding(.top, 24)`) : `RoundedRectangle(cornerRadius: 22)` 160×160, fill `bgCard`, bordure `border` :
    - Anneau : `Circle().stroke(FudoColor.accent, lineWidth: 5)` 62 pt + `47` au centre (`.fudoFont(.metric(24))`, `textPrimary`).
    - `DAY 12 / 30` : `.fudoFont(.label(12, weight: .bold))`, `.kerning(1)`, `textPrimary`.
    - `flame.fill` + `11` : `FudoGradient.flame` / `celebrationGold`, `.fudoFont(.stat(13))`.
    - ⚠️ **Valeurs de démo assumées** (divergence #6) : c'est une affiche du widget, pas l'état du joueur (qui est au jour 1). Le documenter dans le fichier.
  - Étapes : `VStack(alignment: .leading, spacing: 14)`, `.fudoFont(.body(15, weight: .medium))`, `textPrimary`, numéro en `textSecondary`.
  - `Later` : bouton texte centré au-dessus du CTA, `.fudoFont(.headline(15))`, `textSecondary`, `padding(.bottom, 12)`.
  - CTA `I've added it` : Capsule `accent`.
  - **Les deux boutons font la même chose** : `viewModel.finish()`. On ne peut pas vérifier qu'un widget a été posé (aucune API) → mentir sur la différence serait pire que l'assumer. `I've added it` est le chemin fier, `Later` le chemin honnête.
- **Animations :** le mock entre en fade + scale 0.94 → 1 (`AppAnimation.slow`), et son anneau se **trace** de 0 à 47/99 en 0.6 s — le widget se remplit sous ses yeux. Étapes en cascade à 0.4 s.
- **Transition → Home :** `viewModel.finish()` → `flags.markFullyCompleted()` → `onFinished()` → `RootView.refresh()` → `evaluateRoute()` → `cover = nil` → **la cover tombe sur le Home jour 1**. `Haptics.success()` sur `finish()` (c'est une validation, pas une transition).
- **État écrit — CHECKPOINT 3 :** `hasCompletedOnboarding = true` · `hasFinishedPostPaywall = true` · `contract = nil` (le brouillon est mort : le défi existe en base).

- [ ] **Step 1 : Câbler OB 19 sur `OnboardingLoaderScreen` + `commitChallenge()` à l'étape 1**
- [ ] **Step 2 : Ajouter le test `committingTwiceCreatesOneChallenge`**
- [ ] **Step 3 : Écrire `WelcomeDojoScreen.swift` et `WidgetPromoScreen.swift` + câbler**
- [ ] **Step 4 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 5 : Commit**

```bash
git commit -am "feat(onboarding): OB 19-21 — challenge commit, the dojo and the widget promo"
```

---

### Task 21 : Le routage et le hold-lock

**Files:**
- Modify: `FUDO/App/RootView.swift`
- Modify: `FUDO/App/AppState.swift`

- [ ] **Step 1 : Brancher `RootView` sur les flags**

```swift
struct RootView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var flags = OnboardingFlags()
    @State private var cover: FudoCover?

    var body: some View {
        MainTabView()
            .environment(appState)
            .preferredColorScheme(.dark)
            .fudoCover(item: $cover) { cover in
                switch cover {
                case .onboarding:
                    OnboardingFlowView(store: gameStore, flags: flags, onFinished: refresh)
                case .paywall:
                    PaywallPlaceholderView()      // trial-expired path — Session 6
                default:
                    EmptyView()
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
    }

    private func refresh() {
        gameStore.processRolloverIfNeeded()
        appState.hasActiveChallenge = gameStore.activeChallenge != nil
        // The HOLD-LOCK: "onboarding completed" is not enough — the post-paywall
        // trio must be finished too, or a kill at OB 19 would drop him into an app
        // with no reminder, no dojo, no widget pitch.
        appState.hasCompletedOnboarding = flags.isFullyDone
        evaluateRoute()
    }
    // evaluateRoute() unchanged: !hasCompletedOnboarding → .onboarding
    //                           !entitlementActive       → .paywall
    //                           else                     → nil
}
```

- [ ] **Step 2 : Mettre à jour le commentaire de seam dans `AppState.swift`**

```swift
/// Fed by OnboardingFlags via RootView.refresh(): true only once BOTH the paywall
/// is past and the post-paywall trio is done (the hold-lock).
var hasCompletedOnboarding = true   // default true = the seeded DEBUG player is onboarded
```
⚠️ Le défaut reste `true` : sur un lancement DEBUG seedé, `refresh()` l'écrase avec `flags.isFullyDone` dès `onAppear` — et Task 22 fait marquer les flags par le seed. Sur un vrai fresh install (Release), `flags.isFullyDone` est faux → onboarding ✓.

- [ ] **Step 3 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 4 : Commit**

```bash
git commit -am "feat(onboarding): route the funnel with the post-paywall hold-lock"
```

---

### Task 22 : Le rejeu DEBUG (sans quoi rien n'est testable)

**Files:**
- Modify: `FUDO/Core/Services/GameStore.swift` (extension `#if DEBUG`)
- Modify: `FUDO/Core/Services/DebugSeed.swift`
- Modify: `FUDO/Features/Settings/Views/DebugMenuSection.swift`

> **Le piège** (identifié à la lecture, pas sur device) : `DebugSeed.seedIfNeeded` crée un `PlayerState` à chaque lancement DEBUG. `ensurePlayer` étant un **fetch-or-create**, un onboarding rejoué sur une base seedée récupérerait le joueur à OVR 61 au lieu d'en créer un à 43 — le contrat afficherait un nombre qui n'est pas celui du tunnel. Il faut un wipe qui ne recrée **aucun** joueur (les deux wipes existants en créent un : `reseed` replaie le seed, `blank` appelle `ensurePlayer`).

- [ ] **Step 1 : Ajouter `debugReplayOnboarding()` à `GameStore`**

```swift
/// Wipes everything and leaves the store with NO player — the only state the
/// onboarding can actually run against (ensurePlayer is fetch-or-create: a
/// leftover player would hand the funnel a stale OVR instead of the one the
/// answers just produced). Arms seedDisabled so the launch auto-seed doesn't
/// resurrect a player behind the funnel, and clears the onboarding flags.
func debugReplayOnboarding(flags: OnboardingFlags = OnboardingFlags()) {
    wipeAll(DayLog.self)
    wipeAll(TaskRule.self)
    wipeAll(Challenge.self)
    wipeAll(PlayerState.self)
    player = nil
    activeChallenge = nil
    pendingRankUp = nil
    save()
    UserDefaults.standard.set(true, forKey: DebugSeed.seedDisabledKey)
    flags.reset()
    NotificationService.cancelDailyReminder()
}
```

- [ ] **Step 2 : Le seed marque l'onboarding fait**

Dans `DebugSeed.seed(context:now:)`, après les asserts :
```swift
// The seeded player IS an onboarded player: without this, every DEBUG launch
// would land on the funnel instead of the Home the seed exists to feed.
OnboardingFlags().markFullyCompleted()
```
Et dans `GameStore.debugWipe(reseed:)`, la branche blanche (`ensurePlayer`) doit faire de même — un joueur "vierge onboardé" (frame 01b) est, par définition, passé par l'onboarding.

- [ ] **Step 3 : Ajouter l'action au menu DEBUG**

Dans `DebugMenuSection` : une row **"Replay onboarding"** avec `confirmationDialog` (comme les autres), qui appelle `store.debugReplayOnboarding()`. ⚠️ Après le wipe, la cover d'onboarding doit se lever : `RootView` ne réévalue qu'au `refresh()` (scene-active / onAppear). Reco : l'action pose un `appState.hasCompletedOnboarding = false` juste après le wipe → la cover monte immédiatement. Sinon Romain doit background/foreground l'app, ce qui est un piège de plus.

- [ ] **Step 4 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 5 : Commit**

```bash
git commit -am "feat(debug): replay onboarding — wipe to a no-player state and reset the flags"
```

---

### Task 23 : La preview Xcode du flow

**Files:**
- Modify: `FUDO/Features/Onboarding/Views/OnboardingFlowView.swift` (bloc `#if DEBUG` en bas)

> **Le double piège acté (carnet 2026-07-15)** : (1) la preview lance la VRAIE app → `FUDOApp` est déjà une coquille vide sous `XCODE_RUNNING_FOR_PREVIEWS` ✓ ; (2) **`container.mainContext` ne retient PAS son `ModelContainer`** → un container local de closure est désalloué, SwiftData reset le contexte, et la preview crashe ("destroyed by ModelContext.reset"). Le factory DOIT garder le container en `static let`.

- [ ] **Step 1 : Écrire `OnboardingPreviewFactory` (pattern acté)**

```swift
#if DEBUG
/// Pattern acté 2026-07-15: the factory OWNS the container in a `static let` —
/// `container.mainContext` does not retain it, and a deallocated container makes
/// SwiftData reset the context mid-preview.
@MainActor
private enum OnboardingPreviewFactory {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // ONE shared Schema — never the variadic ModelContainer(for:) initializer
        // (iOS 17 duplicate-metadata crash, carnet 2026-07-12).
        guard let container = try? ModelContainer(for: FudoSchema.schema, configurations: configuration) else {
            fatalError("preview container")
        }
        return container
    }()

    /// No player, no challenge — the state the funnel actually runs against.
    static let store = GameStore(modelContext: container.mainContext)

    static let flags = OnboardingFlags(defaults: UserDefaults(suiteName: "preview.onboarding") ?? .standard)
}

#Preview("Onboarding — full funnel") {
    OnboardingFlowView(store: OnboardingPreviewFactory.store,
                       flags: OnboardingPreviewFactory.flags,
                       onFinished: {})
        .preferredColorScheme(.dark)
}
#endif
```
⚠️ La preview ne jouera **pas** les vidéos de façon fiable dans le canvas (AVFoundation y est capricieux) → le fallback image doit s'y afficher. C'est un bon test du chemin de secours.

- [ ] **Step 2 : Compile-only** — Expected: BUILD SUCCEEDED.
- [ ] **Step 3 : Commit**

```bash
git commit -am "chore(onboarding): preview factory for the full funnel"
```

---

### Task 24 : Clôture de session

- [ ] **Step 1 : L'UNIQUE run de tests de la session**

Run: `xcodebuild test -scheme FUDO -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: toutes les suites passent — les nouvelles (`OnboardingStepTests`, `OnboardingFlagsTests`, `ShockMathTests`, `OnboardingCopyTests`, `OnboardingViewModelTests`) **et les anciennes** (surtout `ChallengeSetupViewModelTests`, `GameStoreTests`, `OVREngineTests` : l'onboarding touche à leurs chemins).

> ⚠️ **Règle durcie** (carnet 2026-07-12) : **un seul run par session, MÊME pour debugger un échec.** Si ça casse : analyse statique + crash logs (`~/Library/Logs/DiagnosticReports`), fix committé **non vérifié**, vérification par Romain en Cmd+U. Ne pas relancer.

- [ ] **Step 2 : Nettoyage machine**

```bash
pkill -f xcodebuild ; xcrun simctl shutdown all
```

- [ ] **Step 3 : Mettre à jour `CLAUDE.md`**

Ajouter au **Carnet de notes** une ligne datée résumant : les décisions D1-D7 telles que tranchées par Romain · le pattern "1 seul `ChallengeSetupViewModel`, 4 skins" · le piège `ensurePlayer` + seed (d'où `debugReplayOnboarding`) · le choix dissolve-loop vs ping-pong et pourquoi · le fait que OB 14 est une **démo** (aucun `checkTask`) · les 2 checkpoints + le hold-lock · l'ajout de `ringWidth` à `HoldToConfirm` · l'ajout de `Rank.displayName` (si accordé).

Mettre aussi à jour la section **Features du MVP** : l'onboarding n'est plus "à construire".

- [ ] **Step 4 : `git status` doit être vide**

```bash
git status   # zéro orphelin non tracké (règle d'hygiène de fin de session)
```

- [ ] **Step 5 : GATE ROMAIN FINAL — le tunnel de bout en bout**

Sur device (Cmd+R), via **Settings > DEBUG > Replay onboarding** :
1. Le tunnel complet, OB 00 → Home jour 1, sans blocage.
2. **Le kill test ×3** : tuer l'app (a) au milieu du quiz → repart à OB 00 ; (b) juste après la signature → repart au paywall, protocole intact ; (c) à OB 19/20 → repart à OB 18, le défi n'est pas dupliqué.
3. Le Home affiche bien **jour 1**, l'OVR du contrat, les règles composées, le rang Novice.
4. Le rappel quotidien est **réellement planifié** (Réglages iOS).
5. Aucun bouton mort, aucun écran vide, aucun placeholder.

---

## Self-review (fait — écarts relevés et traités dans le plan)

**Couverture du brief :** les 25 écrans ont chacun leur bloc (id · purpose · copy exacte · UI · animations · transition · état). Règles globales couvertes : barre calculée (Task 1 + test), Bebas onboarding-only (`.onboardingDisplay`, Tasks 3), `OnboardingAnswers` consommé par les 5 destinations (shock OB 06, reflection OB 09, preset OB 11, startingOVR OB 10, projection OB 13, recut OB 02), kill-safety 2 checkpoints + hold-lock (Tasks 17/18/21), vidéo + fallback (Task 2), ping-pong (D5), review natif (Task 15), notifs réelles (Task 19), ctaSpamGuard (Task 5), haptiques de transition (Task 5), une idée / un CTA par écran.

**Écarts détectés et résolus :**
1. **D1** — l'ordre du brief rend l'OVR d'OB 10 non final. Non résoluble sans décision → décision + reco, et le VM est écrit pour l'option A.
2. **D2** — "starts tomorrow" contredit le moteur ; le piège de l'onboarding du soir n'était dans aucune source → surfacé.
3. **Le `Challenge` créé à la signature** aurait fait tourner l'horloge du jour 1 derrière le paywall → déplacé à OB 19 (ce que l'écran dit déjà).
4. **`ensurePlayer` + seed DEBUG** → l'onboarding aurait affiché l'OVR seedé. `debugReplayOnboarding` (Task 22) sans quoi la session n'est pas testable.
5. **`HoldToConfirm.ringWidth`** manquant pour l'anneau 148 pt → paramètre ajouté (Task 14).
6. **`Rank.displayName`** absent, déjà dupliqué en local par Progression → proposition Core, accord Romain requis (Task 10).
7. **Frames vs moteur** : "MASTER" à 78, "CLASSIC" sur 30 d, "1.5 seconds", "6:30 AM", emojis → 7 divergences loguées, toutes résolues côté moteur/convention.
8. **`ShockMath.headline` privée** aurait bloqué le `CountUpText` → passée internal (Task 8, Step 1).
9. **Ordre des options vs ordre des enums** (`Procrastination`) → liste explicite côté écran, l'enum ne bouge pas (le barème le lit).
10. **Le canvas de signature dans un `ScrollView`** → conflit de gestes identifié, `scrollDisabled(isDrawing)` proposé, à vérifier device.

**Placeholders :** aucun "TBD" / "à définir". Les seules valeurs non finales sont **explicitement** : les stubs S6 (`PricingCopy`, `PaywallGateView`, gardés par D7) et les 3 témoignages d'OB 15 (marqués en dur dans le code, action pré-submit — cf. le point ouvert de D4). Tout le reste est livré définitif.

**Décisions :** D1-D7 tranchées par Romain le 2026-07-15, répercutées dans les blocs d'écran concernés (OB 10/13/16/17 pour D1 · OB 19/20 pour D2 · OB 11 pour D3 · OB 15/18/21 pour D4 · Act 0 pour D5 · OB 18 pour D6 · OB 17 pour D7).

**Cohérence des types :** `OnboardingStep`, `OnboardingDraft`, `OnboardingFlags`/`ContractSnapshot`, `ShockMath.Result`, `OnboardingCopy.*`, `OnboardingViewModel.*` — signatures identiques entre leur définition (Tasks 1/4/5) et leurs usages (Tasks 3/6→20). `ChallengeSetupViewModel`, `GameStore`, `OVREngine`, `Rank`, `PresetCatalog` : lus dans le code existant, appelés verbatim, jamais redéclarés.

