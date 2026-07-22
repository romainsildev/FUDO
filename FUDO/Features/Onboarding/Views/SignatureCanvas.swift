import SwiftUI

/// A finger signature on a dark card. Not a drawing tool: no colours, no undo.
/// The host screen owns a single "Clear" (tester batch #1, 2026-07-16) that
/// empties `strokes` and revokes the signature fact — the canvas itself stays dumb.
///
/// Nothing is persisted. The strokes live in the screen's `@State` and die with
/// it — the mark has no legal weight and no product use, and storing a biometric
/// scribble would be a personal-data liability for zero gain. What survives is
/// the FACT that he signed (`hasSignature`), nothing else.
struct SignatureCanvas: View {
    @Binding var strokes: [[CGPoint]]
    /// Raised while his finger is down so the host ScrollView can stand back —
    /// otherwise a vertical stroke scrolls the page instead of drawing.
    @Binding var isDrawing: Bool
    var onStrokeEnded: () -> Void

    private static let lineWidth: CGFloat = 2.5

    var body: some View {
        // Canvas, not a Path per point: rebuilding a 300-point view tree on every
        // touch move stutters. This draws immediately.
        Canvas { context, _ in
            for stroke in strokes {
                context.stroke(path(for: stroke),
                               with: .color(FudoColor.textPrimary),
                               style: StrokeStyle(lineWidth: Self.lineWidth,
                                                  lineCap: .round, lineJoin: .round))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDrawing {
                        isDrawing = true
                        strokes.append([value.location])
                    } else {
                        strokes[strokes.count - 1].append(value.location)
                    }
                }
                .onEnded { _ in
                    isDrawing = false
                    onStrokeEnded()
                }
        )
    }

    /// Quadratic curves through the midpoints — a hand's line, not a polyline.
    private func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        guard points.count > 1 else {
            // A tap is still a mark: draw the dot rather than nothing.
            path.addEllipse(in: CGRect(x: first.x - Self.lineWidth / 2,
                                       y: first.y - Self.lineWidth / 2,
                                       width: Self.lineWidth, height: Self.lineWidth))
            return path
        }
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
