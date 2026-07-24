import SwiftUI

/// Shared geometry so the node rows and the connector canvas agree on where each portrait sits.
/// The portrait lives in a fixed-width lane pinned to one edge, so its centre is constant
/// regardless of the portrait's own diameter (current node is larger but same centre).
enum RankPathMetrics {
    static let rowHeight: CGFloat = 128
    static let laneWidth: CGFloat = 88
    static let portraitNormal: CGFloat = 60
    static let portraitCurrent: CGFloat = 84

    static var laneCenter: CGFloat { laneWidth / 2 }

    /// Even index → left lane, odd → right lane (the soft serpentine; amplitude tuned at render).
    static func center(index: Int, width: CGFloat) -> CGPoint {
        let x = index.isMultiple(of: 2) ? laneCenter : width - laneCenter
        return CGPoint(x: x, y: rowHeight * (CGFloat(index) + 0.5))
    }
}

/// The descending RANK PATH: Novice at the top → Sensei at the bottom, six nodes on a soft
/// Duolingo-style serpentine. The traversed connector (up to the current rank) is solid
/// vermillon; everything below is a dead dotted line. The current rank sits high early in a
/// challenge, so it's visible without scrolling; locked ranks pull the scroll down.
struct RankPathView: View {
    let nodes: [RankNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("THE PATH")
                .fudoFont(.caption(13))
                .tracking(1.5)
                .foregroundStyle(FudoColor.textSecondary)

            ZStack(alignment: .top) {
                Canvas { context, size in draw(connectorsIn: context, size: size) }
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        RankPathNodeView(node: node, portraitOnLeft: index.isMultiple(of: 2))
                            .frame(height: RankPathMetrics.rowHeight)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: RankPathMetrics.rowHeight * CGFloat(nodes.count))
        }
    }

    /// A soft cubic between consecutive portrait centres; solid up to the current rank, dotted
    /// once we cross into the still-locked ranks.
    private func draw(connectorsIn context: GraphicsContext, size: CGSize) {
        guard nodes.count >= 2 else { return }
        for index in 0..<(nodes.count - 1) {
            let start = RankPathMetrics.center(index: index, width: size.width)
            let end = RankPathMetrics.center(index: index + 1, width: size.width)
            let midY = (start.y + end.y) / 2

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end,
                          control1: CGPoint(x: start.x, y: midY),
                          control2: CGPoint(x: end.x, y: midY))

            let traversed = nodes[index + 1].state != .future
            if traversed {
                // Bright vermillon dotted trail up to the current rank (02 Progression).
                context.stroke(path, with: .color(FudoColor.accent),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [0.1, 10]))
            } else {
                context.stroke(path, with: .color(FudoColor.textSecondary.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0.1, 11]))
            }
        }
    }
}
