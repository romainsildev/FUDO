import SwiftUI

/// SHEET destinations — detent .medium, grabber, swipe-down. Quick consult / picker.
enum FudoSheet: Identifiable {
    case flame, reminderTime, shareCard
    var id: Int {
        switch self {
        case .flame: return 0
        case .reminderTime: return 1
        case .shareCard: return 2
        }
    }
}

extension View {
    func fudoSheet<Content: View>(
        item: Binding<FudoSheet?>,
        @ViewBuilder content: @escaping (FudoSheet) -> Content
    ) -> some View {
        sheet(item: item) { sheet in
            content(sheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(FudoColor.bgPrimary)
        }
    }
}
