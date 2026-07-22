import SwiftUI
import UIKit

/// Renders a `ShareCardView` to a 1080×1920 PNG-ready `UIImage`. The card is
/// designed at 360×640 points; scale 3 lands exactly on 1080×1920. Dark is forced
/// and the image is opaque (no transparent letterboxing in the share sheet).
@MainActor
enum ShareCardRenderer {
    static let scale: CGFloat = 3

    static func render(data: ShareCardData, variant: ShareCardVariant) -> UIImage? {
        let card = ShareCardView(data: data, variant: variant)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Thin bridge to the system share sheet. User-initiated only (they tap Share,
/// then pick a target in the OS sheet) — we never auto-send.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
