import SwiftUI

/// A card to present for sharing — the variant plus its resolved data. Identifiable
/// so the hooks present it with `.shareCardPreview(item:)`.
struct ShareCardRequest: Identifiable {
    let variant: ShareCardVariant
    let data: ShareCardData
    let id = UUID()
}

/// WYSIWYG share screen: the exact 9:16 card the user gets, big, over the ink,
/// with a single Share CTA into the native share sheet. Rendering is near-instant
/// but the export path still carries loading + failure + retry (paywall-grade rule:
/// a dead share button ships nothing).
struct ShareCardPreviewView: View {
    let request: ShareCardRequest
    @Environment(\.dismiss) private var dismiss

    private enum ExportState: Equatable { case idle, rendering, failed }
    @State private var exportState: ExportState = .idle
    @State private var shareItem: SharePayload?

    var body: some View {
        ZStack {
            FudoColor.bgPrimary.ignoresSafeArea()
            VStack(spacing: 24) {
                topBar
                cardPreview
                    .frame(maxHeight: .infinity)
                shareButton
            }
            .padding(.horizontal, FudoSpacing.screenMargin)
            .padding(.top, 12)
            .padding(.bottom, FudoSpacing.contentBottom)
        }
        .sheet(item: $shareItem) { payload in
            ActivityView(items: [payload.image])
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .fudoFont(.headline(15, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(FudoColor.bgCard))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    /// The live card scaled to fit — identical to the rendered image, so the
    /// preview never lies about the export.
    private var cardPreview: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, geo.size.height * 9 / 16)
            let scale = width / ShareCardView.canvas.width
            ShareCardView(data: request.data, variant: request.variant)
                .frame(width: ShareCardView.canvas.width, height: ShareCardView.canvas.height)
                .scaleEffect(scale)
                .frame(width: width, height: width * 16 / 9)
                .clipShape(RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                        .strokeBorder(FudoColor.border, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        Button {
            export()
        } label: {
            HStack(spacing: 8) {
                if exportState == .rendering {
                    ProgressView().tint(FudoColor.textPrimary)
                } else {
                    Image(systemName: exportState == .failed ? "arrow.clockwise" : "square.and.arrow.up")
                        .fudoFont(.headline(16, weight: .semibold))
                }
                Text(shareButtonLabel)
                    .fudoFont(.headline(17))
            }
            .foregroundStyle(FudoColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: FudoSpacing.ctaHeight)
            .background(Capsule().fill(FudoColor.accent))
        }
        .buttonStyle(.plain)
        .disabled(exportState == .rendering)
        .animation(AppAnimation.standard, value: exportState)
    }

    private var shareButtonLabel: String {
        switch exportState {
        case .idle:      return "Share"
        case .rendering: return "Preparing…"
        case .failed:    return "Try again"
        }
    }

    private func export() {
        guard exportState != .rendering else { return }
        Haptics.medium()
        exportState = .rendering
        // A frame's delay lets the button flip to its loading state before the
        // (synchronous) render blocks the main actor — the spinner is honest.
        Task { @MainActor in
            if let image = ShareCardRenderer.render(data: request.data, variant: request.variant) {
                exportState = .idle
                shareItem = SharePayload(image: image)
            } else {
                exportState = .failed
            }
        }
    }
}

/// Identifiable wrapper so the native share sheet presents via `.sheet(item:)`.
private struct SharePayload: Identifiable {
    let image: UIImage
    let id = UUID()
}

extension View {
    /// Present the share preview over any screen: `.shareCardPreview($request)`.
    func shareCardPreview(_ item: Binding<ShareCardRequest?>) -> some View {
        fullScreenCover(item: item) { request in
            ShareCardPreviewView(request: request)
                .preferredColorScheme(.dark)
        }
    }
}

#if DEBUG
#Preview("Share preview — daily") {
    ShareCardPreviewView(request: ShareCardRequest(
        variant: .daily,
        data: ShareCardData(rank: .ascetic, ovr: 61, streak: 4,
                            dayNumber: 12, totalDays: 30, presetTitle: "Monk Mode 30",
                            startOVR: nil, endOVR: nil)))
    .preferredColorScheme(.dark)
}

#Preview("Share preview — challenge end") {
    ShareCardPreviewView(request: ShareCardRequest(
        variant: .challengeEnd,
        data: ShareCardData(rank: .warrior, ovr: 76, streak: 21,
                            dayNumber: 30, totalDays: 30, presetTitle: "Monk Mode 30",
                            startOVR: 43, endOVR: 76)))
    .preferredColorScheme(.dark)
}
#endif
