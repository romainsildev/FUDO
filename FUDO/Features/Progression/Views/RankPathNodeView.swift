import SwiftUI

/// One node of the rank path: a circular sensei portrait plus its label, laid out with the
/// portrait pinned to one side (the serpentine zig-zag) and the copy on the other. The portrait
/// sits in a fixed-width lane so its centre stays constant across sizes — the connectors in
/// `RankPathView` are drawn to those exact centres.
///
/// - discovered → colour head + "reached …"
/// - current    → colour head, enlarged, vermillon halo + "current rank · OVR …"
/// - future     → black silhouette + "unlocks at OVR …" (tap → wiggle only, MVP)
struct RankPathNodeView: View {
    let node: RankNode
    let portraitOnLeft: Bool

    var body: some View {
        HStack(spacing: 14) {
            if portraitOnLeft {
                portrait
                label(alignment: .leading)
            } else {
                label(alignment: .trailing)
                portrait
            }
        }
        .padding(.horizontal, 2)
    }

    private var portrait: some View {
        RankPortrait(node: node)
            .frame(width: RankPathMetrics.laneWidth, height: RankPathMetrics.laneWidth)
    }

    private func label(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(node.name.uppercased())
                .fudoFont(.title(node.state == .current ? 21 : 17))
                .foregroundStyle(nameColor)
            Text(node.subtitle)
                .fudoFont(.caption(13))
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
    }

    // The current node's name stays cream — the ring and the OVR badge already carry
    // the vermillon; "current rank" underneath takes the accent instead (2026-07-23).
    private var nameColor: Color {
        switch node.state {
        case .current:    return FudoColor.textPrimary
        case .discovered: return FudoColor.textPrimary
        case .future:     return FudoColor.textSecondary
        }
    }

    private var subtitleColor: Color {
        node.state == .current ? FudoColor.accent : FudoColor.textSecondary
    }
}

/// The circular portrait itself — colour / silhouette, current halo + enlarge, future wiggle.
private struct RankPortrait: View {
    let node: RankNode
    @State private var wiggle = false

    private var diameter: CGFloat {
        node.state == .current ? RankPathMetrics.portraitCurrent : RankPathMetrics.portraitNormal
    }

    var body: some View {
        ZStack {
            haloIfCurrent
            Circle().fill(FudoColor.bgCard)
            portraitImage.clipShape(Circle())
            Circle().strokeBorder(ringColor, lineWidth: node.state == .current ? 3 : 1)
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .bottom) { ovrBadge }
        .rotationEffect(.degrees(wiggle ? 3 : 0))
        .contentShape(Circle())
        .onTapGesture { triggerWiggleIfFuture() }
        .animation(AppAnimation.standard, value: node.state)
    }

    /// Locked ranks are a total mystery — a pitch-dark disc, no art leaking through
    /// (Romain, 2026-07-23: "complètement noir"). Discovered/current show the portrait.
    @ViewBuilder private var portraitImage: some View {
        if node.state == .future {
            Circle().fill(FudoColor.silhouette)
        } else if let head = SenseiAssetProvider.headImage(for: node.rank) {
            head
                .resizable()
                .scaledToFill()
                .frame(width: diameter, height: diameter)
        } else {
            Image(systemName: "person.fill")
                .fudoFont(.glyph(diameter * 0.42))
                .foregroundStyle(FudoColor.textSecondary)
        }
    }

    /// The current node carries its OVR as a vermillon capsule riding the portrait's
    /// bottom edge — the number lives on the path, not in the copy (Prog FINAL).
    @ViewBuilder private var ovrBadge: some View {
        if let ovr = node.currentOVR {
            Text("OVR \(ovr)")
                .fudoFont(.stat(12))
                .foregroundStyle(FudoColor.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Capsule().fill(FudoColor.accent))
                .offset(y: 11)
        }
    }

    private var ringColor: Color {
        switch node.state {
        case .current:    return FudoColor.accent
        case .discovered: return FudoColor.border
        case .future:     return FudoColor.border.opacity(0.6)   // barely-there rim on the dark disc
        }
    }

    @ViewBuilder private var haloIfCurrent: some View {
        if node.state == .current {
            Circle()
                .fill(FudoColor.accent.opacity(0.28))
                .frame(width: diameter + 28, height: diameter + 28)
                .blur(radius: 16)
        }
    }

    private func triggerWiggleIfFuture() {
        guard node.state == .future else { return }
        // A single slow nudge out-and-back (0.4–0.6 s ease), not the old snappy
        // 4× shake — "locked" reads without breaking the premium-motion rule.
        Task {
            withAnimation(AppAnimation.standard) { wiggle = true }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(AppAnimation.standard) { wiggle = false }
        }
    }
}
