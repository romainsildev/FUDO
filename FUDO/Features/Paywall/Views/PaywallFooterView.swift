import SwiftUI

/// Review-mandatory footer links: Restore purchases · Terms of Use · Privacy
/// Policy — small, quiet, all present before any purchase (URLs from AppConfig,
/// the same ones Settings links).
struct PaywallFooterView: View {
    let isRestoring: Bool
    let onRestore: () -> Void
    let onShowTerms: () -> Void
    let onShowPrivacy: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onRestore) {
                HStack(spacing: 5) {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(FudoColor.textSecondary)
                    }
                    Text("Restore purchases")
                }
            }
            .disabled(isRestoring)

            separator

            Button("Terms of Use", action: onShowTerms)

            separator

            Button("Privacy Policy", action: onShowPrivacy)
        }
        .fudoFont(.caption(11))
        .foregroundStyle(FudoColor.textSecondary)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Text("·")
    }
}
