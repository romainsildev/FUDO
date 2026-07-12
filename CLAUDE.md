# Projet : FUDO — Monk Mode Challenge

> Ce fichier est la mémoire persistante de Claude Code. Le lire avant chaque prompt. Le tenir à jour (voir Carnet de notes en bas).

## Concept

App iOS native de discipline gamifiée : l'user entre en **monk mode** — un défi à durée fixe (30/60/90 j) où il valide chaque jour ses non-négociables. Sa constance fait monter son **OVR** (0-99, type NBA2K) et évoluer son **sensei** à travers 6 rangs. Rater un jour fait chuter l'OVR, pas recommencer le défi. L'app ne bloque rien : la contrainte est psychologique (OVR qui chute, streak cassée, rang perdu).

Persona : homme 16-25, TikTok self-improvement, cluster monk mode / lock in / discipline.

## Stack (figée — ne jamais dévier)

- Swift / SwiftUI, **iOS 17+** (`@Observable`, SwiftData)
- **SwiftData** pour toute persistance (100 % local, App Group partagé avec le widget)
- **WidgetKit** (widget small + medium)
- **RevenueCat** (subscriptions, trial-first) + **PostHog** (analytics, host EU, wrapper `Analytics.swift`, zéro capture en DEBUG) — les DEUX seules dépendances tierces autorisées
- **UNUserNotificationCenter** : notifications locales uniquement, zéro push serveur
- **AUCUN backend, AUCUNE auth, AUCUN compte, AUCUN réseau** (hors RevenueCat et PostHog). Ne jamais en proposer.
- EN only : toutes les UI strings en anglais (via `Localizable.xcstrings`, base EN, pas d'autre langue)

## Design

- **L'app EST dark** : pas de light mode, `.preferredColorScheme(.dark)` forcé. Pas de logique dark/light.
- Palette ACTÉE (SUMI conservée sous la DA cartoon, décision 2026-07-11 — tokens dans `Core/DesignSystem/Colors.swift`, ne jamais hardcoder un hex dans une view ; doubler chaque couleur dans l'Asset Catalog, mêmes noms, pour le widget) :
  - Fonds : `bgPrimary` #121110 (noir encre chaud) · `bgCard` #1C1A17 · `border` #2A2724 (bordure 1 px sur TOUTES les cards, jamais d'ombre)
  - Texte (jamais de blanc pur) : `textPrimary` #FAF0E6 · `textSecondary` #A89F92
  - Vermillon (10 % max de l'écran) : `accent` #E34234 (CTA, rings, flamme, ensō, barres) · `accentPressed` #FF5140 · `accentDeep` #7A1F17 (fonds badges rang)
  - Deltas OVR : `positive` #34C759 · `negative` #FF453A — la FLÈCHE ▲/▼ porte le vert/rouge, les barres/rings restent vermillon (décision 2026-07-11)
  - `celebrationGold` #E8B44A : réservé aux bursts de célébration (journée 100 %, rank-up)
  - Interdits absolus : violet, bleu électrique, vert en accent UI, dégradés néon (territoires des 4 concurrents + signe d'app vibe-codée)
- Spacing/radius : marges écran 20 · padding card 16 (20 pour les majeures) · inter-sections 40 · radius card 24 `.rect(style: .continuous)` (nested 8) · CTA = Capsule hauteur 56 · rings 6 pt lineCap `.round`
- Fonts : SF Pro Display (titres, OVR géant en `.monospacedDigit()`), SF Pro Text (body). **Bebas Neue** (TTF embarqué `Resources/Fonts/`, déclaré UIAppFonts) = hooks display ONBOARDING uniquement, jamais dans l'UI app.
- **Animations 0.4-0.6 s ease-in-out** partout (lent = premium). Jamais rapides/sèches.
- Haptics : boutons principaux, validations (hold-to-check progressif), transitions onboarding — **nulle part ailleurs**.
- Confetti/célébrations réservés aux milestones : journée 100 %, montée de rang, fin de défi. Le reste = signes discrets.
- Chaque écran : états success / loading / failure pensés. Loading quasi nul (local) SAUF paywall (fetch produits) et partage → loading + failure avec retry obligatoires. **Jamais d'écran vide** (empty state = CTA de relance).
- Ton copy : direct, 2e personne, dur-mais-satisfait, viril sans caricature. Factuel sur l'échec ("Yesterday: incomplete. OVR -4."), jamais culpabilisant-verbeux.
- Dossier `DesignReference/` (hors build) : screenshots d'inspiration — le consulter pour toute tâche visuelle.

## Conventions

- MVVM léger : `@Observable` (jamais `ObservableObject`), un ViewModel par feature, pas par sous-view.
- Un fichier = une view. Organisation par feature (voir `STRUCTURE.md` du pack de build).
- `NavigationStack` (jamais `NavigationView`). TabView **4 onglets pilule flottante** : Today · Progress · Stats · Settings. Conventions nav (prd/12 §1) : **tab switch** (jamais de push cross-onglet) · **sheet** medium (flamme, time picker, share) · **push** (tab bar MASQUÉE : habit detail, sous-écrans Settings) · **cover** (onboarding, paywall, setup standalone, challenge complete, rank-up) · **alert ×2** destructif. Onboarding/paywall/covers en `.fullScreenCover`.
- Noms en anglais (code + fichiers). UI strings en anglais.
- Pas de force unwrap (`!`), pas de `try!` sur les opérations SwiftData — toujours gérer l'erreur.
- **Toute constante de gameplay vit dans `Core/Game/GameConfig.swift`** (taux OVR, pénalités, decay, grace period, caps). Jamais de nombre magique dans une view ou un service.
- **`OVREngine` est la source de vérité unique** de la formule OVR (voir `DATA-MODEL.md`) : la projection d'onboarding, le Home, le rollover et le widget appellent le même moteur. Ne jamais dupliquer un calcul OVR.
- Widget : ne touche JAMAIS SwiftData — il lit un `WidgetSnapshot` JSON (Codable) écrit dans UserDefaults App Group par `WidgetBridge` côté app (modèle P7).

## Features du MVP (liste exhaustive — ne RIEN builder d'autre)

1. **Défi à durée fixe** avec presets modifiables (Monk Mode 30 / 60 / Hardcore 90 / Classique 75). 1 seul défi actif. Règles éditables jusqu'à J3, verrouillées ensuite.
2. **Checklist quotidienne** hold-to-check 1,5 s (anneau + haptic progressif + burst + delta OVR flottant). Décocher = reprise exacte des points. Anti-farming (plafond OVR/jour).
3. **OVR 0-99 + 6 rangs sensei** (Novice → Sensei), persiste entre les défis, decay d'inactivité léger.
4. **Widget** (small : streak + OVR + jour X/Y ; medium : + 3 tâches restantes) + **notifs locales** (rappel quotidien conditionnel, soir, streak en danger, J-1 trial, decay, montée de rang — cap 2/jour).
5. **Carte de partage 9:16** (sensei + OVR + rang + streak + jour X/Y + branding) — rendu SwiftUI → UIImage → share sheet.
6. **Stats** (onglet habitudes, acté 2026-07-11 — prd/10 + prd/12 §5) : segmented 7/30/défi, carte résumé, top/flop, liste habitudes (sparkline + tendance) + push détail habitude (3 tuiles, graph, timeline step-by-step, conseil local). Agrégation locale des `DayLog.checks`, zéro donnée nouvelle. Frontière : Progress = le défi et le rang, Stats = les habitudes.

Hors scope (ne jamais coder, même si "facile") : communauté/leaderboard, heatmap détaillée (v1.1), radar domaines (le champ `domain` existe en base, pas d'UI), rest day (le champ `restDayWeekday` existe en base, pas d'UI — D5), AI coach, journaling, blocage d'apps (v2), auth/sync, localisation, light mode, export de données.

## Règles de gameplay (invariants — ne pas casser)

- Journée = minuit → minuit local, **grace period silencieuse jusqu'à 2 h du matin** (rollover à 2 h).
- Pas de validation rétroactive : hier est mort.
- Streak = journées 100 % consécutives. Incomplète à la clôture → pénalité OVR + streak cassée.
- Anti-farming : somme des deltas de tâches = plafond du jour ; check/uncheck = neutre exact ; aucune tâche ne paie 2×.
- Le rang persiste entre défis. Decay uniquement sans défi actif, plancher = bas du rang courant (on ne perd jamais un rang par decay).
- Trial expiré sans achat → paywall, données conservées (argument de réactivation). User payant → plus JAMAIS de paywall.

## Pièges connus (leçons des sources — tester systématiquement)

- App tuée puis relancée : ne doit PAS redéclencher une notif/animation à tort ; restauration de navigation propre.
- Review prompt : `SKStoreReviewController` natif UNIQUEMENT, jamais de modal custom.
- Paywall : produits qui ne chargent pas = CTA mort = rejet Apple Guideline 2.1 → loading + retry obligatoires. Prix complet + mention renouvellement auto visibles sur l'écran.
- `PrivacyInfo.xcprivacy` requis pour chaque SDK (RevenueCat, PostHog) + APIs "required reason" — rejet automatique sinon.
- Restore purchases fonctionnel + chemin "payant → plus de paywall" testés avant chaque soumission.
- Zéro placeholder, bouton mort ou "coming soon" dans un build soumis.
- SwiftData : vérifier que Claude n'a pas créé des doublons de fichiers modèles ; pas de `try!` silencieux.
- Médias qui débordent : contraindre via `GeometryReader` + `frame`, pas des paddings au hasard.

## Hygiène du repo (obligatoire — leçon du 2026-07-12 : 4 ensō perdus par manipulation d'assets hors process)

- **Source de vérité des assets = CE repo (git).** `~/Downloads` = zone de transit, jamais une source. Ne JAMAIS supprimer/écraser un asset sans avoir vérifié qu'une copie est committée (`git log --follow <fichier>`).
- `Assets.xcassets` : JAMAIS d'image posée en vrac dedans — uniquement des `.imageset`/`.appiconset` avec leur `Contents.json`.
- Tout asset bundlé (image, font, vidéo) vit sous `FUDO/` (dossier synchronisé Xcode) — `FUDO/Resources/Welcome/`, `FUDO/Resources/Fonts/`, `FUDO/Assets.xcassets/`. Rien d'autre à la racine du repo que : `CLAUDE.md`, `.gitignore`, `docs/`, `DesignReference/`, `FUDO/`, `FUDO.xcodeproj/`, `FUDOTests/`, `FUDOUITests/`.
- `DesignReference/` = screenshots des frames Figma (fournis par le chef d'orchestre session par session, sous-dossiers `app/`, `onboarding/`). HORS build (jamais dans un target) — à CONSULTER pour toute tâche visuelle : c'est la maquette de référence, pas une inspiration.
- Pas de fichier temporaire/brouillon dans le repo ; pas de doublons (`Foo 2.swift`) — si Xcode en génère un, le signaler et le résoudre immédiatement.
- `xcuserdata/`, `.DS_Store`, `*.xcuserstate` = ignorés via `.gitignore` — ne jamais les committer.
- Toute suppression de fichier = commande servie à Romain, jamais exécutée en autonomie.
- Fin de session : après le commit de checkpoint, `git status` doit être vide (zéro orphelin non tracké).

## Principes pour Claude

- **Machine 16 GB (M5 base) — la charge vient des BUILDS, pas des subagents.** Subagents OK pour écrire du code/des fichiers. INTERDIT : deux `xcodebuild` en même temps, quelle que soit la source. Vérif par étape = compile-only SANS booter de simulateur (`xcodebuild build -destination 'generic/platform=iOS Simulator'`). Suite de tests complète (qui boote un sim) : UNE fois par session, jamais par étape, jamais en parallèle d'autre chose. Zéro sim booté en tâche de fond. La vérif visuelle/device = Romain, dans Xcode, sur son iPhone (Cmd+R) — jamais la session.
- Plan mode avant tout build multi-écrans ; **ultrathink pour les tâches visuelles/UI**.
- Si tu modifies une feature, vérifier que les autres marchent encore (surtout OVREngine ↔ Home ↔ widget).
- Ne JAMAIS modifier la formule OVR ou les constantes de `GameConfig` sans accord explicite de Romain.
- Avant de refactorer : demander confirmation.
- Les décisions produit appartiennent à Romain : proposer options + reco 1 ligne, ne rien trancher seul.
- Mettre à jour ce fichier (features, conventions découvertes, carnet) au fil du build.

## Carnet de notes (append-only, tenir à jour à chaque session)

| Date | Note (convention découverte, piège rencontré, décision de build) |
|---|---|
| 2026-07-12 | Session 1 (data layer) : 4 @Model + OVREngine + GameStore + DebugSeed + câblage livrés. Décisions actées : 1 pénalité PAR jour manqué (DayLogs synthétiques au rollover, en ordre) · `OnboardingAnswers` typée (barème dans les enums) · seed = replay moteur base 49 → OVR 61 / streak 4 / J12 · `lastDayClosedAt` = lendemain du jour clos (horloge idle du decay). |
| 2026-07-12 | PIÈGE SwiftData : plusieurs `ModelContainer` créés via la variadique `ModelContainer(for: Type.self, …)` dans un même process (host app + tests unitaires in-memory) → crash SIGTRAP interne SwiftData à l'insert (métadonnées `.unique` dupliquées, iOS 17). Fix : UNE instance `Schema` partagée (`FudoSchema.schema`), tout container se construit dessus. **Fix NON VÉRIFIÉ** (run de tests stoppé par Romain, machine saturée) — à vérifier Cmd+U. OVREngineTests : 100 % verts au run initial. |
| 2026-07-12 | RÈGLE DURCIE : 1 seul `xcodebuild test` par session, MÊME pour debugger un échec — analyse statique (crash logs `~/Library/Logs/DiagnosticReports`) + fix committé non vérifié + vérif par Romain dans Xcode. Fin de session : `pkill -f xcodebuild` + `xcrun simctl shutdown all`. |
| 2026-07-12 | Crash tests persistant malgré le Schema partagé (Cmd+U Romain : EXC_BREAKPOINT à l'insert de PlayerState). Évidence : host + 1 container de test = vert ; crash quand les containers S'ACCUMULENT. Triple fix : (1) FUDOApp = coquille vide sous session de test (env `XCTestSessionIdentifier`/`XCTestConfigurationFilePath`) — ni container réel, ni seed, ni rollover pendant les tests ; (2) suites SwiftData `@Suite(.serialized)` ; (3) `SwiftDataTestSupport.freshContainer()` = UN container in-memory pour tout le process de test, vidé fetch+delete entre tests (`ModelContext.delete(model:)` batch pas fiable en iOS 17). Toute nouvelle suite SwiftData DOIT passer par `SwiftDataTestSupport`, jamais créer son container. Vérif = Cmd+U Romain. |
| 2026-07-12 | Session Home : HomeView 3 états (01/01b/01c) + FlameSheetView + SenseiStageView (hooks pulse/slump/celebrate — l'art réel remplacera `react()`/`celebrate()` et le modifier de posture, call sites intacts). GameStore : agrégats READ-ONLY ajoutés (`effectiveToday`, `displayCalendar`, `todayNumber`, `dayLog(on:)`, `totalChecksAllTime`) — les views ne touchent jamais `Date.now`, toujours l'horloge du store. `HomePlaceholderView` = shim `@Environment(GameStore.self)` → `HomeView(store:)` car MainTabView hors scope session — renommer le call site au prochain passage shell puis supprimer le shim. Célébration 100 % = one-shot via triggers en mémoire du VM (relaunch ne rejoue RIEN, piège connu). Cover challengeSetup = stub avec bouton close temporaire (le vrai flow possédera ses sorties). Compile-only vert ; vérif visuelle = Romain (Cmd+R). |
| 2026-07-12 | Session hold-to-check : `HoldToConfirm` (Core/DesignSystem) = geste signature réutilisable — Button + ButtonStyle `isPressed` (le ScrollView annule la pression nativement au drag vertical → ring rewind 0,3 s, zéro combat de gestures), horloge = Task annulable (source de vérité du confirm, exactly-once via `sealed`), ring = trim animé sur la shape passée en param. Haptique progressive light→medium→heavy aux quarts + `.success` au seal (`.heavy` dispo pour la confirmation de défi). Constantes dans `HoldToConfirmMetrics` + `ParticleBurstMetrics` (jamais dans GameConfig — gameplay only). `ParticleBurstView` (DesignSystem) généralise le burst ; `GoldBurstView` = preset gold par-dessus. Row : seal echo + burst + "+X OVR" flottant au niveau ROW (survivent au flip checked) ; delta affiché = relecture du `TaskCheck.ovrDelta` enregistré (zéro calcul dupliqué). Uncheck = long-press 0,5 s → confirmationDialog destructif, refund exact, aucun burst. Compile-only vert ; feel du geste = vérif Romain sur device. |
| 2026-07-12 | Session rollover UI : scene-active déjà câblé (RootView.refresh, session 1) — ajouté le timer foreground : `GameStore.timeUntilNextRollover` (borne = minuit effectif + graceHours, horloge du store) + `HomeViewModel.watchRolloverWhileForeground()` en boucle `.task` sur HomeView (idempotent, double-fire scene/timer inoffensif). ATTENTION Task.sleep = continuous clock : un saut d'horloge machine ne déclenche PAS le timer en cours — pour tester, régler l'horloge AVANT de lancer l'app. Banner "Yesterday: incomplete. OVR -X." : métrique = PÉNALITÉ du closure (`checksTotal − ovrDelta`), pas le net du jour (les gains live étaient déjà affichés la veille) — badge OVR aligné sur la même métrique. Multi-jours manqués → "N days incomplete. OVR -Σ." (à valider Romain). Dismiss persisté par jour effectif dans UserDefaults (`home.incompleteBanner.dismissedDay`) — relaunch ne re-montre pas un banner fermé. |
