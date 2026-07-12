import SwiftData

/// Single Schema instance for the whole process. Every ModelContainer (app, tests)
/// MUST build from this — constructing several containers from the variadic
/// `ModelContainer(for: Challenge.self, …)` initializer registers duplicate entity
/// metadata for the `.unique` attributes and crashes inside SwiftData (iOS 17 bug,
/// hit when unit tests create in-memory containers next to the host app's).
enum FudoSchema {
    static let schema = Schema([Challenge.self, TaskRule.self, DayLog.self, PlayerState.self])
}
