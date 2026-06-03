import SwiftUI

enum RootTab: Hashable {
    case discover
    case saved
    case me
    case merchant
}

@MainActor
final class AppSession: ObservableObject {
    @Published var activeTab: RootTab = .discover

    /// Deep-link destination - the slug we want Discover to push when the
    /// active tab settles. Drives `locals://m/<slug>` and Universal Links.
    @Published var pendingMerchantSlug: String?

    /// First-run flag. The onboarding sheet shows on cold start when this is
    /// nil. Tapping "Get started" sets it - subsequent launches skip
    /// straight to Discover.
    @AppStorage("locals.onboarded") var hasOnboarded: Bool = false

    /// User-controlled toggle for the anonymous crowd pulse. Off by default;
    /// the customer turns it on once - then dwell-time near a merchant
    /// quietly contributes the "N here in the last hour" signal.
    @AppStorage("locals.pulse.enabled") var pulseEnabled: Bool = false
}
