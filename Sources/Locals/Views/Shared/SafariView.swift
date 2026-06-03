import SwiftUI
import SafariServices

/// In-app Safari for the Stripe Checkout flow. Apple's 2024 reader pattern
/// allows external purchase URLs for merchant-side B2B services; we open
/// the URL here so the customer never leaves the app shell.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(LocalsTheme.accent)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
