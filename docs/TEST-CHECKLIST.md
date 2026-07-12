# FUDO — Checklist de test manuel (device)

> Doc perso de Romain, en français. Couvre les sessions 0→2 (shell/tabs, data+seed, Home complet, hold-to-check, flame sheet, rollover, polish pass). Ordre = un run complet le plus rapide possible : les tests destructifs (changement d'heure, reset seed, no-challenge) sont à la FIN.
>
> Légende : 📱 = iPhone physique requis (haptiques, Liquid Glass réel, feel 60 fps) · 🖥️ = simulateur OK.
>
> **Reset du seed** (setup récurrent) : supprimer l'app du device/sim (appui long → Supprimer l'app) → relancer depuis Xcode (Cmd+R). Le seed ne se rejoue que si la base est vide. État attendu après seed : jour 12/30, OVR 61 ASCETIC, streak 4, 3/5 tâches cochées, 5 règles.

---

## 1. Lancement & shell (session 0)

- ✅   🖥️ Install fraîche (reset seed ci-dessus) → l'app s'ouvre direct sur Today, AUCUN écran vide, aucun crash.
- ✅ 🖥️ L'app est 100 % dark, même si le device est en mode clair (réglages iOS → apparence claire → l'app reste sombre).
- ✅ 🖥️ 4 onglets visibles : Today · Progress · Stats · Settings ; Progress/Stats/Settings = placeholders (normal à ce stade).
- [✅] 📱 Changer d'onglet → haptique légère à chaque switch.
- [✅] 🖥️ Dans Stats ou Settings : "Push demo →" → l'écran pushé MASQUE la tab bar ; back natif la restaure.

## 2. Home — header épinglé & pills (items 3/5 du polish)

- [✅] 🖥️ Header = avatar rond + pill "DAY 12 / 30" + pill flamme 🔥 4 — les trois alignés, rien d'autre.
- [✅] 🖥️ AVATAR : le visage du sensei REMPLIT le cercle 34 pt (plus de cercle à moitié vide, pas de bord noir).
- [peut pas verifier mais ca a l'air oui ] 📱 Pills en vrai Liquid Glass sur iOS 26 (reflets natifs) ; sur simulateur/OS antérieur → recette material (vérifier les 2 chemins si possible).
- [✅] 🖥️ Pill flamme : flamme en dégradé vermillon→or (pointe or), compte "4" blanc cassé, fond verre.
- [✅] 🖥️ Tap avatar → bascule sur l'onglet Progress (pas de push).
- [✅] 🖥️ Pendant N'IMPORTE quel scroll de la checklist : le header ne bouge JAMAIS.

## 3. Home — bloc hero (sensei + OVR)

- [✅] 🖥️ Sensei ASCETIC dans le ring, arc vermillon ≈ 3/5, halo chaud derrière lui.
- [✅] 🖥️ "61" géant sous le sensei + "ASCETIC" vermillon en majuscules espacées.
- [✅] 🖥️ Badge "▲ +X.X today" VERT à droite du rang (3 checks du seed → ~+0.7).
- [✅] 🖥️ Tap sur le bloc sensei/OVR → bascule sur Progress (même affordance que l'avatar).
- [✅] 🖥️ Section "TODAY'S PROTOCOL" + compteur "3 / 5" vermillon à droite ; 2 cartes non cochées EN HAUT, 3 cochées barrées en bas, légèrement estompées.
- [✅] 🖥️ La dernière carte reste atteignable AU-DESSUS de la tab bar flottante (pas cachée dessous).

## 4. Hero collapsant (item 2 du polish)

- [non] 📱 Scroll down LENT : le hero rétrécit + s'estompe en continu, AUCUN saut ; le strip compact 44 pt apparaît sous le header (tête sensei + "61 · ASCETIC" + "3/5" + mini ring).
- [ ] 📱 Scroll up : tout s'inverse, continu, 60 fps (aucun frame drop perceptible).
- [ ] 🖥️ Strip visible → tap dessus → Progress.
- [ ] 🖥️ Hero déployé (haut de scroll) → le strip est invisible ET ne vole aucun tap.
- [ ] 🖥️ Arrêter le scroll à mi-course : l'état intermédiaire est stable (pas d'animation qui "finit" toute seule).

## 5. Hold-to-check (LE geste — item 1 du polish)

- [✅] 📱 Presser-tenir une carte non cochée ~1,0 s : ring vermillon se dessine autour de la carte + haptique progressive (léger → moyen → fort) + carte légèrement enfoncée.
- [✅] 📱 À 1,0 s : haptique success + burst vermillon au niveau du cercle + "+X.X OVR" flotte et s'efface + la carte passe cochée (barrée) et GLISSE en bas de liste.
- [✅] 🖥️ Le sensei fait sa micro-réaction (respiration + halo) à CHAQUE check.
- [✅] 🖥️ Le ring du jour passe à 4/5, le compteur aussi, le badge "▲ today" augmente.
- [✅] 📱 Relâcher AVANT 1 s : ring rembobine en douceur (~0,3 s), RIEN validé, AUCUNE haptique supplémentaire.
- [✅] 📱 Re-presser pendant le rembobinage : le ring repart proprement de zéro (pas de complétion anticipée).
- [✅] 📱 Commencer un hold puis SCROLLER verticalement : le hold s'annule immédiatement, le scroll gagne, ring rembobine.
- [✅] 🖥️ Spam tap rapide sur une carte : rien ne se valide (le tap seul ne coche plus).

## 6. Uncheck (reprise exacte des points)

- [✅] 🖥️ Noter l'OVR/badge → long-press ~0,35 s sur une carte COCHÉE → dialog "Uncheck this task? / Points will be taken back."
- [✅] 🖥️ "Uncheck" → carte redevient non cochée, remonte dans la liste, ring/compteur redescendent, badge diminue du delta EXACT (aucun burst, aucune célébration).
- [✅] 🖥️ "Keep it" → strictement rien ne change.
- [✅] 🖥️ Anti-farming : check → uncheck → re-check la même carte = même delta qu'au premier check (comparer le "+X.X OVR" flottant les 2 fois).

## 7. Day complete — célébration (item 7 du polish)

- [✅] 📱 Cocher les 2 dernières cartes. Au DERNIER check, séquence ~1,8 s : flash du ring qui se scelle → burst or+vermillon émis DEPUIS le ring (pas du centre) + grande respiration du sensei + aura dorée → retombée douce. Haptiques : medium au seal, success au burst.
- [ ] 🖥️ État final (frame 01c) : ring plein scellé avec glow, "▲ +X.X today", "Day 12: complete. Return tomorrow.", lien "Share my day ›" (stub, ne fait rien — normal), 5/5, toutes les cartes barrées.
- [ ] 🖥️ KILL l'app (swipe app switcher) → relancer : état day-complete intact mais la célébration ne se REJOUE PAS (piège connu).
- [ ] 🖥️ Long-press uncheck sur une carte → l'état day-complete se défait proprement (message disparaît, ring rouvre à 4/5) ; re-check → la célébration se rejoue (action live légitime).

## 8. Flame sheet (D3 — frame 09)

- [ ] 🖥️ Tap pill flamme → sheet à MI-hauteur, fond sombre, grabber visible, swipe-down pour fermer ; AUCUNE navigation sortante depuis la sheet.
- [ ] 📱 Hero : grande flamme dégradé vermillon→or avec glow qui "respire" lentement (~1,8 s/cycle, subtil).
- [ ] 🖥️ "4" géant + "day streak".
- [ ] 🖥️ Semaine M T W T F S S : jours faits = pastille vermillon ✓ · jour raté = pastille morte barrée (slash) · AUJOURD'HUI = ring partiel (3/5, miroir du ring principal) + halo doux + lettre vermillon · à venir = contour vide.
- [ ] 🖥️ Stats : TOTAL CHECKS = 53 avec le seed intact (10 jours × 5 + 3) · BEST STREAK = 6 (jours 1-6 du seed).
- [ ] 🖥️ Cocher une tâche puis rouvrir la sheet : le ring "today" et TOTAL CHECKS se mettent à jour.

## 9. Persistance & relaunch (pièges connus)

- [ ] 🖥️ Kill + relaunch à n'importe quel moment : même état exact (checks, OVR, streak, jour X/Y), aucune animation/célébration rejouée, aucun écran blanc.
- [ ] 🖥️ Backgrounder l'app (home) 30 s puis revenir : rien ne bouge (pas de reset, pas de double rollover).

## 10. Rollover & grace period (⚠️ changements d'heure — faire EN DERNIER avant le no-challenge)

> Setup horloge : Réglages Système Mac → Général → Date et heure → désactiver "Régler automatiquement" → changer → le simulateur suit l'horloge du Mac. Remettre l'auto à la fin. Sur iPhone physique : Réglages → Général → Date et heure.

- [ ] 🖥️ **J+1 normal** : laisser 1-2 tâches non cochées, kill, horloge → demain 9h00, relancer : jour 13/30, checklist RESET (0/5, ring vide), banner "Yesterday: incomplete. OVR -X." (chiffre en rouge), sensei AFFAISSÉ (posture tassée, désaturé), streak pill à 0, badge "▼" rouge.
- [ ] 🖥️ **Banner** : tap X → disparaît en douceur ; kill + relaunch → il ne REVIENT PAS (dismiss persisté pour ce jour).
- [ ] 🖥️ **Journée 100 % puis J+1** : compléter le jour, horloge → demain 9h, relancer : PAS de banner, sensei normal, streak +1, checklist reset.
- [ ] 🖥️ **Kill 3 jours** : kill, horloge → +3 jours 9h, relancer : banner "3 days incomplete. OVR -X." (pénalités sommées), streak 0, jour saute de 3.
- [ ] 🖥️ **Grace 1h30** : horloge → demain 01h30, relancer : ENCORE le même jour (numéro inchangé, checks intacts, aucun banner, aucune pénalité, aucune mention à l'écran — silencieux).
- [ ] 🖥️ **Rollover 2h30** : horloge → demain 02h30, relancer : nouveau jour, veille clôturée (banner si incomplète).
- [ ] 🖥️ **Timer foreground** : horloge → 01h59 AVANT de lancer l'app, lancer, rester sur Home ~90 s : à "02h00" la checklist se reset EN DIRECT à l'écran (banner glisse si veille incomplète). ⚠️ Changer l'horloge PENDANT que l'app tourne ne déclenche PAS le timer (horloge continue) — toujours régler avant lancement.
- [ ] 🖥️ **Pas de validation rétroactive** : après un rollover, aucune UI ne permet de cocher hier (la liste ne montre que les tâches du jour — vérifier qu'aucun chemin n'y donne accès).

## 11. État no-challenge (frame 01b — setup code temporaire)

> Setup : pas encore d'UI d'abandon. Temporairement dans `DebugSeed.seed` : `return` juste après `store.ensurePlayer(...)` (et commenter les 3 `assert` du bas). App supprimée → relancer. REVERT le fichier après le test (`git checkout FUDO/Core/Services/DebugSeed.swift`).

- [ ] 🖥️ Home jamais vide : sensei estompé dans le ring VIDE (pas d'arc), halo réduit, OVR + rang persistants affichés, pill header = "FUDO", pill flamme grisée 🔥 0.
- [ ] 🖥️ Copy : "Your rank awaits." + "The dojo doesn't close. Start again."
- [ ] 📱 CTA vermillon "Start a new challenge" (haptique au tap) → cover plein écran ChallengeSetup (placeholder) → X temporaire en haut à droite referme.
- [ ] 🖥️ Tap pill flamme grisée → sheet : flamme GRISE morte + "Streak dead. Rebuild." (si streak à 0).

## 12. Accessibilité (passe rapide, optionnel)

- [ ] 📱 VoiceOver : les cartes exposent les actions "Check" / "Uncheck" (rotor actions) — le hold n'est pas obligatoire.
- [ ] 📱 VoiceOver : avatar, bloc OVR, strip et pill flamme ont des labels parlants.

---

## 📌 Doc vivant — règle pour les prochaines sessions

**Chaque session future DOIT ajouter ici sa propre section de checks (en français), au bon endroit du parcours de test** : nouvelle feature = nouvelle section (ou items ajoutés à une section existante), avec action exacte, résultat attendu, setup si besoin, et le flag 📱/🖥️. Une feature sans ses items de test ici = session non terminée.
