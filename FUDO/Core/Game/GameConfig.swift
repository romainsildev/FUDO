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
