#if DEBUG
import SwiftUI
import SwiftData

/// Canvas preview for the (reverted, original S4) Progression screen — kept in its own
/// file so `ProgressionView.swift` stays byte-for-byte the restored trophy room. Uses the
/// shared, seeded `AppPreviewFactory` (OVR 61 Ascetic, Day 12/30, streak 4).
#Preview("Progression — trophy room") {
    if let store = AppPreviewFactory.store, let container = AppPreviewFactory.container {
        ProgressionView(store: store)
            .modelContainer(container)
            .preferredColorScheme(.dark)
    } else {
        Text("Preview container failed")
    }
}
#endif
