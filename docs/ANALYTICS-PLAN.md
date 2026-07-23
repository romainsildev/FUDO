# ANALYTICS-PLAN — plan d'events PostHog du MVP

Date : 2026-07-10. Décision actée : PostHog (host EU). Répond au finding **C2** de `AUDIT-KNOWLEDGE-COMPLET.md` ("le funnel long est impilote sans events"). Sources : PRD 02/03/05/07, `knowledge/10-croissance/01`, `knowledge/05-dev-ios/06` §6, `knowledge/05-dev-ios/07`.

**Principe** : on instrumente pour répondre à UNE question — *où le funnel saigne-t-il ?* — pas pour collectionner de la data. Chaque event ci-dessous a un consommateur identifié (un funnel, une rétention, un seuil). Rien d'autre.

## Conventions

- **Noms** : `snake_case`, verbe au passé (`trial_started`, pas `start_trial`).
- **Anonyme strict** : pas de `identify()`, pas d'email/nom (pas de comptes), jamais l'âge exact (bracket uniquement). L'anonymous ID PostHog suffit.
- **Wrapper obligatoire** : tous les appels passent par `Core/Services/Analytics.swift` (protocol + impl PostHog + impl no-op DEBUG). Jamais `PostHogSDK.shared.capture` en direct dans une vue — sinon impossible de couper/mocker.
- **DEBUG = zéro capture** (opt-out ou projet PostHog séparé) : le seed de dev polluerait tous les funnels.
- Setup (verbatim knowledge) : `PostHogConfig(apiKey: "phc_XXX", host: "https://eu.posthog.com")`.

---

## 1. Events — liste exhaustive MVP

### 1.1 Cycle de vie

| Event | Propriétés | Déclenchement |
|---|---|---|
| *(auto)* `Application Opened` / `Application Installed` | — | Autocapture lifecycle PostHog (laisser activé : sert de dénominateur download→trial et de base D1/D7/D30) |
| `app_opened_from` | `source: notification\|widget` + `notification_id` le cas échéant | Uniquement deep links (l'ouverture directe est couverte par l'autocapture) |

### 1.2 Funnel onboarding (OB 00→21 + paywall — l'actif n°1)

> ⚠️ **UX v2** : l'onboarding est passé à 25 écrans (OB 00→21, prd/02). La table `step→screen` ci-dessous est le squelette PRE-UX v2 (15 écrans) ; à l'instrumentation (Session 6bis, `docs/ONBOARDING-PLAN.md` fait foi), **re-baser `step` sur l'index OB** (0…21) et compléter les noms `screen` — l'event reste **un seul event paramétré** (`onboarding_screen_viewed`), pas 25 events. Les splits UX v2 (splash OB 00, welcome éclaté 01a/b/c, split OVR OB 10/OB 13, pain selector OB 02) deviennent des valeurs de `screen`.

| Event | Propriétés | Déclenchement |
|---|---|---|
| `onboarding_screen_viewed` | `step` (index OB), `screen` (nom stable) | `onAppear` de CHAQUE écran. Un seul event paramétré, pas N events |
| `onboarding_question_answered` | `step`, `question`, `answer` (valeurs anonymes ci-dessous) | À la réponse, avant transition |
| `onboarding_challenge_composed` | `preset`, `duration_days`, `rules_count`, `rules_edited: bool` | Écran 9, validation du protocole inline |
| `onboarding_projection_viewed` | `starting_ovr`, `projected_ovr` | Écran 10 |
| `onboarding_first_check_done` | — | Écran 11, hold-to-check démo validé (flamme jour 0) |
| `review_prompt_requested` | `placement: "onboarding_peak"` | Écran 12 (on log la *demande* — iOS décide de l'affichage, non observable) |
| `notif_permission_answered` | `granted: bool` | Écran 14, retour du popup système |
| `onboarding_completed` | `duration_seconds`, `screens_seen` | Sortie écran 15 → PaywallGate |

Table `screen` (step → nom) : 1 `welcome` · 2 `scroll_hours` · 3 `age` · 4 `procrastination` · 5 `shock_stat` · 6 `goals` · 7 `struggle` · 8 `reflection` · 9 `challenge_composition` · 10 `ovr_projection` · 11 `first_check` · 12 `social_proof` · 13 `commitment` · 14 `notifications` · 15 `summary_price`.

Valeurs `answer` anonymes : é2 `scroll_hours: "<2h"|"2-4h"|"4-6h"|"6h+"` · é3 `age_bracket: "13-17"|"18-24"|"25-34"|"35+"` (JAMAIS l'âge exact — il ne sert qu'au calcul local) · é4 `procrastination: weekly|monthly|stopped_lying` · é6 `goals: [array des 6 slugs]` · é7 `struggle: quit_fast|3_days_max|cant_start` · é13 `commitment: extremely|very|a_little`.

Ces réponses sont aussi posées en **person properties** (`$set` : `scroll_hours`, `struggle`, `commitment`, `preset`) → segmentation des funnels/rétention par persona (ex. "les `cant_start` convertissent-ils moins ?").

### 1.3 Paywall (PRD 03)

| Event | Propriétés | Déclenchement |
|---|---|---|
| `paywall_viewed` | `placement: onboarding\|relaunch\|trial_expired` | Affichage écran (le dénominateur du revenu/impression) |
| `paywall_plan_selected` | `plan: weekly\|annual` | Tap sur une row de plan |
| `paywall_dismissed` | `placement`, `seconds_on_screen`, `plan_selected` | X (après les 3 s) |
| `paywall_products_failed` | `reason` | Fetch offerings échoué (signal tech : CTA mort = rejet 2.1 + trials perdus) |
| `trial_started` | `plan: "weekly"`, `price_usd: 5.99`, `trial_days: 3` | Achat sandbox/prod confirmé RevenueCat |
| `purchase_completed` | `plan`, `price_usd`, `is_trial_conversion: bool` | customerInfo update (annual direct, ou conversion trial→paid) |
| `purchase_failed` | `plan`, `reason: cancelled\|error` | Retour transaction |
| `purchase_restored` | — | Restore réussi |
| `subscription_expired` | `had_trial: bool` | customerInfo : entitlement "pro" perdu (churn signal) |

⚠️ **Source de vérité revenu = RevenueCat**, pas PostHog. Les events client servent aux funnels/corrélations ; les $ se lisent dans le dashboard RC.

### 1.4 Activation (PRD 05)

| Event | Propriétés | Déclenchement |
|---|---|---|
| `challenge_started` | `preset`, `duration_days`, `rules_count`, `origin: onboarding\|home\|post_challenge`, `challenges_completed_before` | `GameStore.startChallenge` |
| `task_checked` | `day_index`, `tasks_done`, `tasks_total`, `is_first_ever: bool` | Hold-to-check validé (`is_first_ever` = le vrai premier check hors démo = aha moment candidat) |
| `task_unchecked` | `day_index` | Confirmation uncheck |
| `day_completed` | `day_index`, `streak`, `ovr`, `tasks_total` | Ring scellé 100 %. **`day_index == 1` = métrique d'activation** |

### 1.5 Rétention (PRD 05/07 + widget/notifs)

| Event | Propriétés | Déclenchement |
|---|---|---|
| `day_failed` | `day_index`, `tasks_missed`, `ovr_delta` | Rollover d'un jour incomplet (moteur) |
| `streak_milestone` | `streak: 3\|7\|14\|21\|30\|60\|90` | Franchissement (une fois par palier) |
| `rank_up` | `rank`, `ovr`, `day_index` | Changement de rang détecté par GameStore |
| `widget_detected` | `families: ["small","medium"]` | Au foreground, via `WidgetCenter.getCurrentConfigurations` — capture uniquement si l'état a changé (proxy fiable d'installation du widget) |
| `notification_tapped` | `id: daily_reminder\|evening_reminder\|streak_danger\|trial_d1\|decay_warning\|rank_up` | `UNUserNotificationCenterDelegate.didReceive` |

### 1.6 Fin de défi + partage (PRD 07)

| Event | Propriétés | Déclenchement |
|---|---|---|
| `challenge_completed` | `duration_days`, `days_complete`, `days_missed`, `ovr_start`, `ovr_end`, `rank_end` | Séquence verdict affichée |
| `challenge_abandoned` | `day_index`, `days_complete`, `ovr` | Confirmation abandon (Settings) |
| `next_challenge_chosen` | `option: next_preset\|restart_harder` | CTA du hook 3 (le taux ici = LA métrique de rétention inter-défis de Romain) |
| `share_card_viewed` | `origin: day_complete\|progress\|rank_up\|challenge_end`, `template` | Ouverture ShareCardSheet |
| `share_card_shared` | `origin`, `template`, `activity` | Completion handler du share sheet à `true` (partage réel, pas juste ouvert) |

### 1.7 Signaux de churn

| Event | Propriétés | Déclenchement |
|---|---|---|
| `paywall_viewed {placement: trial_expired}` | — | Trial expiré sans achat → Home remplacée par paywall (déjà en 1.3) |
| `subscription_expired` | — | Déjà en 1.3 |
| `decay_started` | `ovr`, `days_idle` | Premier tick de decay (7 j+ sans défi actif) |
| `data_erased` | — | "Erase all my data" (Settings) — le signal de sortie le plus dur |
| `notif_permission_answered {granted: false}` | — | Déjà en 1.2 — cohorte "sans notifs" à comparer en D7 (le PRD prédit "mort au jour 4") |

Non instrumentable : la désinstallation (proxy = absence d'`Application Opened`) et l'annulation de trial côté Apple avant expiration (visible dans RevenueCat uniquement).

### 1.8 Écrans UX v2 (prd/10 Stats + prd/12 sheet flamme / rank-up cover)

| Event | Propriétés | Déclenchement |
|---|---|---|
| `flame_sheet_viewed` | — | Ouverture du Sheet flamme (tap pill 🔥 du Home) — engagement streak |
| `stats_viewed` | — | `onAppear` de l'onglet Stats |
| `stats_period_changed` | `period: "7d"\|"30d"\|"challenge"` | Changement du segmented Stats |
| `habit_detail_viewed` | `habit` | PUSH détail habitude. ⚠️ **anonyme strict** : `habit` = slug de règle preset (`cold_shower`…) ou `custom_<index>` pour une règle custom — **jamais le titre saisi** (règle libre = PII, cf. §4) |
| `rank_up_shown` | `rank` | COVER rank-up affichée (1× par rang, high-water `highestRankReached`) — distinct de `rank_up` (1.5) qui log le franchissement moteur ; ici = la célébration vue |
| `rank_up_shared` | `rank` | Tap Share sur la COVER rank-up. Consommateur = taux de partage du moment rank-up (le `share_card_shared {origin: rank_up}` de 1.6 couvre le partage réel abouti ; `rank_up_shared` = intention depuis la cover) |

`rank_up` (franchissement, GameStore) existe déjà en 1.5 — **ne pas le dupliquer**. `rank_up_shown`/`rank_up_shared` sont les events de la COVER (D6), consommateur distinct.

**Total : ~31 events.** Ne pas en ajouter au MVP sans consommateur identifié.

---

## 2. Les 5 métriques de pilotage (seuils knowledge)

| # | Métrique | Calcul | Seuil | Source seuil |
|---|---|---|---|---|
| 1 | **Download → trial** | `trial_started` uniques / `Application Installed` (croiser avec downloads App Store Connect) | **≥ 10 %** — en dessous, tout trafic (UGC, ads) = argent jeté dans un entonnoir percé. Itérer l'onboarding jusqu'au seuil AVANT de scaler | Règle Mao + Mal Baron, `10-croissance/01` §2 |
| 2 | **Conversion page produit** | App Store Connect (impressions → downloads) — pas PostHog | **≥ 10 %** | Benchmark base |
| 3 | **Rétention D1/D7/D30** | Retention PostHog sur `Application Opened` | **D1 > 40 %** (50 % excellent) · **D7 > 20 %** (30 %) · **D30 > 10 %** (15 %) | `10-croissance/01` §1 |
| 4 | **Trial → paid** | Dashboard RevenueCat (vérité) ; PostHog : `purchase_completed {is_trial_conversion}` / `trial_started` | **≥ 30 % = bon, < 25 % = urgent à fixer**. Attendre ~40-50 % d'annulations de trial = normal, ne pas paniquer sur les premières cohortes de 10 users | `10-croissance/01` §1 |
| 5 | **Revenu par impression paywall** | Revenu (RC) / `paywall_viewed` | Pas de seuil absolu — c'est LA métrique de comparaison des variantes paywall (actée session pricing, ~500 impressions/variante). PAS la conversion seule | PRD 03 / Parra |

Ordre d'attaque post-launch : d'abord #1 (funnel onboarding), puis #4 (notif J-1 + paywall), puis #3. Cf. `10-croissance/01` §2 : les seuils s'enchaînent.

---

## 3. Dashboard "semaine 1" — les 3 graphiques du matin

À créer dans PostHog AVANT la soumission (10 min), regardés chaque matin post-launch :

1. **Funnel onboarding complet** : `Application Installed` → `onboarding_screen_viewed` step OB 00…21 → `paywall_viewed` → `trial_started`. Le graphique qui répond à "60 % partent à l'écran X" — l'écran qui saigne le plus = la priorité d'itération du jour. Breakdown par `struggle` si volume suffisant.
2. **Trend quotidien download → trial** : `trial_started` uniques / installs uniques, ligne de référence à 10 %. Tant que < 10 % : on itère l'onboarding, on ne scale RIEN.
3. **Activation + rétention early** : cohortes quotidiennes — `day_completed {day_index: 1}` / `challenge_started` (activation jour 1) + courbe rétention D1. Si les gens démarrent un défi mais ne valident pas le jour 1, le problème est dans Home/notifs, pas dans le funnel.

(Semaine 2+ : ajouter trial→paid par cohorte et `next_challenge_chosen` — pas avant, pas de data.)

---

## 4. Conformité

- **Privacy label App Store Connect** (acté, audit C1) : déclarer **Usage Data → Product Interaction** (PostHog) + **Identifiers → Device ID** (PostHog + RevenueCat) + **Purchases** (RevenueCat). Label incohérent avec le comportement observé = rejet (DOC6). Le claim ASO reformulé : "Pas de compte. Ta progression reste sur ton téléphone." (les données *de défi* — vrai ; on ne dit plus "aucune donnée ne quitte le téléphone").
- **Zéro PII** : pas de comptes → rien à collecter. Interdits explicites : `identify()` avec quoi que ce soit d'identifiant, âge exact, texte libre des règles custom (une règle custom peut contenir du perso → tracker `rules_count`, jamais les titres), session replay PostHog (OFF).
- **Host EU** : `https://eu.posthog.com` — dispo, obligatoire ici (GDPR simplifié, `05-dev-ios/07`).
- **PrivacyInfo.xcprivacy** : vérifier que le SDK PostHog embarque son privacy manifest (comme RevenueCat) — check déjà au point 7 de P12.
- Pas de bannière consentement au MVP : analytics anonymes first-party-like, pas d'ads tracking, pas d'ATT (on ne touche pas l'IDFA).

---

## 5. Implémentation — branchement dans PROMPTS-BUILD.md

`PROMPTS-BUILD.md` (l.45) renvoie l'analytics à une "session dédiée hors de ce fichier" : c'est **cette session-ci**. Placement : **Session 6bis — J8, immédiatement après la Session 6 (paywall)**. Rationale : à ce stade onboarding (S5) + paywall (S6) existent = 100 % du funnel critique instrumentable d'un coup, et chaque build TestFlight suivant mesure déjà le download→trial. Les features livrées après (widget, notifs, fin de défi) ajoutent leurs events dans leur propre session via 3 micro-patchs (ci-dessous).

### Patch A — prompt P6bis à insérer après P6 (`/clear` → direct)

```text
Add product analytics with PostHog. Read CLAUDE.md first.

1. Add posthog-ios via SPM. Configure at app launch:
   PostHogConfig(apiKey: [POSTHOG_KEY], host: "https://eu.posthog.com").
   Disable session replay and any autocapture except application
   lifecycle events (Installed/Opened must keep firing).
2. Core/Services/Analytics.swift: a small protocol
   (track(_ event: String, properties: [String: Any]?), set(person:))
   with a PostHogAnalytics impl and a NoopAnalytics used in DEBUG
   builds (zero capture in DEBUG — dev data must never pollute
   funnels). All call sites use this wrapper, NEVER PostHogSDK
   directly. Event names live in one AnalyticsEvent enum (snake_case
   constants) so no string is typed twice.
3. Instrument the EXISTING code per the event table in
   docs/ANALYTICS-PLAN.md (copy it into the project as
   docs/ANALYTICS-PLAN.md first): onboarding (screen_viewed on every
   onAppear with step+screen, question_answered with the anonymized
   values — age as bracket only, never exact), challenge composition,
   projection, first check, review_prompt_requested,
   notif_permission_answered, onboarding_completed; paywall (viewed
   with placement, plan_selected, dismissed with seconds_on_screen,
   products_failed, trial_started, purchase_completed/failed/restored,
   subscription_expired via customerInfo updates); core game
   (challenge_started, task_checked/unchecked, day_completed,
   day_failed, streak_milestone, rank_up) — fire these from GameStore
   (single mutation path), not from views; UX v2 engagement (already
   built screens: flame_sheet_viewed on flame sheet present;
   stats_viewed on Stats tab onAppear; stats_period_changed {period:
   "7d"|"30d"|"challenge"} on segmented change; habit_detail_viewed
   {habit} on habit detail push — {habit} = preset rule slug or
   "custom_<index>", NEVER the user-typed title).
4. Person properties ($set) after onboarding: scroll_hours, struggle,
   commitment, preset. Nothing else. No identify(), no PII, no free
   text ever (custom rule titles are user text — track rules_count
   only).
5. Add [POSTHOG_KEY] to the placeholders handling like
   [REVENUECAT_PUBLIC_KEY] (single Config file).

Do not add any event not listed in docs/ANALYTICS-PLAN.md. Do not
touch UI behavior. ultrathink.
```

Vérifier : events visibles en live dans PostHog (build Release-like ou flag DEBUG inversé temporairement), funnel onboarding OB 00→21 reconstitué, zéro event en DEBUG.
Checkpoint : `git commit -am "feat: posthog analytics" && git tag s6b`

### Micro-patchs sur les sessions suivantes (1 ligne à coller en fin de prompt)

> **Note d'ordonnancement** : Home (S2), Progression (S4) et Stats (S4bis) sont construits AVANT la Session 6bis (le wrapper `Analytics` n'existe pas encore à J2-6). Leurs events — dont `flame_sheet_viewed`, `stats_viewed`, `stats_period_changed`, `habit_detail_viewed` — sont donc câblés en **6bis** en instrumentant le code existant (voir Patch A point 3), PAS inline. Seules les sessions POSTÉRIEURES à 6bis reçoivent un micro-patch inline :

- **P7 (widget)** : `Also fire Analytics "widget_detected" {families} on foreground via WidgetCenter.getCurrentConfigurations, only when the set of installed families changes.`
- **P8 (carte de partage + rank-up cover)** : `Fire Analytics "share_card_viewed" {origin, template} on sheet open and "share_card_shared" {origin, template, activity} only when the activity completion handler returns true. Also fire "rank_up_shown" {rank} when the rank-up cover appears and "rank_up_shared" {rank} on its Share tap (do NOT duplicate the existing "rank_up" GameStore event).`
- **P9 (notifications)** : `In the UNUserNotificationCenterDelegate didReceive handler, fire Analytics "notification_tapped" {id} before routing the deep link.`
- **P11 (fin de défi)** : `Fire Analytics "challenge_completed" {duration_days, days_complete, days_missed, ovr_start, ovr_end, rank_end}, "challenge_abandoned" {day_index, days_complete, ovr}, "next_challenge_chosen" {option}, and "decay_started" {ovr, days_idle} on the first decay tick.`
- **P10 (settings)** : `Fire Analytics "data_erased" just before wiping (last event of the anonymous id).`
- **P12 (audit)** : ajouter un point 11 : `11. Analytics audit: every event in docs/ANALYTICS-PLAN.md fires exactly once at the right moment; zero events in DEBUG; no free-text or exact-age property anywhere.`

### Placeholder à ajouter à la table de PROMPTS-BUILD

| Placeholder | Valeur | Décidé où |
|---|---|---|
| `[POSTHOG_KEY]` | clé projet `phc_…` | dashboard PostHog (projet EU) — clé publique, OK dans le code, centralisée dans Config |

### Étape manuelle (avant P6bis)

```
1. Créer le compte/projet PostHog en région EU → récupérer phc_…
2. (Optionnel mais propre) 2e projet "dev" si on préfère capturer en DEBUG
3. Créer les 3 insights du dashboard semaine 1 (section 3) une fois les
   premiers events TestFlight arrivés
```
