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
