import SwiftUI

/// Loading placeholder for the plan area — two quiet card ghosts on a slow
/// pulse, no spinner circus. The paywall is the ONE screen allowed a real
/// loading state (remote products), so it gets a deliberate one.
struct PaywallSkeletonView: View {
    @State private var dimmed = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
                    .frame(height: 74)
                    .overlay {
                        RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                            .strokeBorder(FudoColor.border, lineWidth: 1)
                    }
            }
        }
        .opacity(dimmed ? 0.45 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                dimmed = true
            }
        }
        .accessibilityLabel("Loading plans")
    }
}
