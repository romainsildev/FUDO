import SwiftUI
import SafariServices

/// In-app SFSafariViewController for the legal pages — keeps the user inside the
/// app (Privacy Policy / Terms) instead of bouncing to the Safari app. Presented
/// as a sheet from Settings via `.sheet(item:)`.
struct SafariLink: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(FudoColor.accent)
        controller.preferredBarTintColor = UIColor(FudoColor.bgPrimary)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
