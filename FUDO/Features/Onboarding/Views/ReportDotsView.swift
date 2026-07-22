import SwiftUI

/// The report's dot-row viz (S5d), two honest modes:
///  - `.week(filled:target:)` — TRAINING: 7 day slots, his sessions filled red,
///    the protocol's target outlined green on the empty slots. The gap between
///    red fills and green outlines IS the deficit.
///  - `.streak` — TRACK RECORD: 7 empty neutral slots, the streak still
///    unwritten. Nothing filled, nothing judged — everything to write.
///
/// Dots pop in with a small per-dot stagger on appearance.
struct ReportDotsView: View {
    enum Mode: Equatable {
        case week(filled: Int, target: Int)
        case streak
    }

    let mode: Mode
    var compact: Bool = false

    @State private var appeared = false

    private static let slots = 7
    private var dotDiameter: CGFloat { compact ? 9 : 13 }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            ForEach(0..<Self.slots, id: \.self) { index in
                dot(at: index)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05),
                               value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    @ViewBuilder private func dot(at index: Int) -> some View {
        switch mode {
        case let .week(filled, target):
            if index < filled {
                Circle()
                    .fill(FudoColor.negative)
                    .frame(width: dotDiameter, height: dotDiameter)
            } else if index < target {
                Circle()
                    .strokeBorder(FudoColor.positive, lineWidth: 1.5)
                    .frame(width: dotDiameter, height: dotDiameter)
            } else {
                emptySlot
            }
        case .streak:
            emptySlot
        }
    }

    private var emptySlot: some View {
        Circle()
            .strokeBorder(FudoColor.border, lineWidth: 1.5)
            .frame(width: dotDiameter, height: dotDiameter)
    }
}

#if DEBUG
#Preview("Dots — trains 1-2, target 4") {
    ZStack {
        FudoColor.bgCard
        ReportDotsView(mode: .week(filled: 2, target: 4))
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Dots — streak unwritten, compact") {
    ZStack {
        FudoColor.bgCard
        ReportDotsView(mode: .streak, compact: true)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
#endif
