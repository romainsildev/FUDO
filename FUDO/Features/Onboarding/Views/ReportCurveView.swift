import SwiftUI

/// The POTENTIAL teaser (S5d): a flat grey dashed line — the average guy going
/// nowhere — and a vermilion curve rising away from it, drawn on appearance.
/// Deliberately number-free: no axis, no OVR — the reveal is the NEXT screen,
/// this only points at it. Vermilion, not green: a promise is the product
/// speaking, never the green/red of recorded history (S5 curve rule).
struct ReportCurveView: View {
    var compact: Bool = false

    @State private var drawn = false

    private var lineWidth: CGFloat { compact ? 2 : 2.5 }
    private var dotDiameter: CGFloat { compact ? 5 : 7 }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // The average guy: flat, grey, going nowhere.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.82))
                    path.addLine(to: CGPoint(x: size.width, y: size.height * 0.82))
                }
                .stroke(FudoColor.border,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))

                // Him on the protocol: same start, then up and away.
                RisingCurve()
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(FudoColor.accent,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                Circle()
                    .fill(FudoColor.accent)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .position(x: size.width - dotDiameter / 2, y: size.height * 0.10)
                    .opacity(drawn ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { drawn = true }
        }
    }
}

/// Ease-in rise from the average's baseline to the top-right corner.
private struct RisingCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.82))
        path.addCurve(to: CGPoint(x: rect.width * 0.98, y: rect.height * 0.10),
                      control1: CGPoint(x: rect.width * 0.45, y: rect.height * 0.82),
                      control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.42))
        return path
    }
}

#if DEBUG
#Preview("Curve — expanded") {
    ZStack {
        FudoColor.bgCard
        ReportCurveView()
            .frame(width: 132, height: 64)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Curve — compact thumbnail") {
    ZStack {
        FudoColor.bgCard
        ReportCurveView(compact: true)
            .frame(width: 100, height: 36)
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
#endif
