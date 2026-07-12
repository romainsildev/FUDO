import Foundation
import SwiftData

/// One non-negotiable of a challenge. Daily recurrence is implicit (no field in MVP).
/// Editable until day GameConfig.rulesLockDay, locked after.
@Model
final class TaskRule {
    @Attribute(.unique) var id: UUID
    var title: String
    var iconName: String       // SF Symbol
    var domain: String?        // v1.1 radar — stored from day one, no UI in MVP
    var isActive: Bool         // a disabled rule doesn't count toward the day
    var sortOrder: Int
    var createdAt: Date
    var challenge: Challenge?

    init(id: UUID = UUID(), title: String, iconName: String, domain: String? = nil,
         isActive: Bool = true, sortOrder: Int, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.domain = domain
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
