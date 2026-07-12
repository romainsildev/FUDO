import Foundation
import SwiftData
@testable import FUDO

/// ONE in-memory ModelContainer for the whole unit-test process, wiped between tests.
///
/// Why: SwiftData on iOS 17 traps (EXC_BREAKPOINT on insert) once a process
/// accumulates several live ModelContainers over a schema carrying `.unique`
/// attributes — even when every container is built from the shared
/// FudoSchema.schema instance. Evidence: one host container + ONE test container
/// ran green; the crash appeared only as containers piled up test after test.
/// A single reused container sidesteps the entire bug class. Both SwiftData
/// suites are `.serialized`, so wipes never race.
@MainActor
enum SwiftDataTestSupport {
    private static let containerResult = Result {
        try ModelContainer(for: FudoSchema.schema,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// The shared container, emptied of every model — call at the top of each test.
    static func freshContainer() throws -> ModelContainer {
        let container = try containerResult.get()
        let context = container.mainContext
        // fetch+delete rather than ModelContext.delete(model:) — the batch variant
        // is unreliable on iOS 17.
        try wipe(DayLog.self, in: context)
        try wipe(TaskRule.self, in: context)
        try wipe(Challenge.self, in: context)
        try wipe(PlayerState.self, in: context)
        try context.save()
        return container
    }

    private static func wipe<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
