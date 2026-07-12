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
