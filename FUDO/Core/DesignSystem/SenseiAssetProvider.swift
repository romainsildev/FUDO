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

    // MARK: - Head crop (header avatar, compact strip)

    /// Top-weighted square crop framing the face, done in PIXEL space so a
    /// `scaledToFill + Circle` mask fills the avatar edge to edge. Fractions
    /// calibrated on the 1024×1536 renders (face center ≈ x 0.5, y 0.19).
    private static let headCropWidthFraction: CGFloat = 0.38  // square side, × art width
    private static let headCropTopFraction: CGFloat = 0.07    // crop top, × art height

    @MainActor private static var headCache: [Rank: Image] = [:]

    /// Face crop for the given rank — nil when the art is missing (call sites
    /// draw the SF Symbol fallback themselves at symbol-appropriate size).
    @MainActor
    static func headImage(for rank: Rank) -> Image? {
        if let cached = headCache[rank] { return cached }
        guard let art = UIImage(named: imageName(for: rank)),
              let cgImage = art.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = width * headCropWidthFraction
        let cropRect = CGRect(x: (width - side) / 2,
                              y: height * headCropTopFraction,
                              width: side,
                              height: side)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        let head = Image(uiImage: UIImage(cgImage: cropped, scale: art.scale, orientation: .up))
        headCache[rank] = head
        return head
    }
}
