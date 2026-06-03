import SwiftUI

@main
struct LocalsApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var session = AppSession()
    @StateObject private var location = LocationManager()
    @StateObject private var merchants = MerchantService()
    @StateObject private var rewards = RewardService()
    @StateObject private var redemptions = RedemptionService()
    @StateObject private var favorites = FavoriteService()
    @StateObject private var owners = OwnerMerchantService()
    @StateObject private var billing = BillingService()
    @StateObject private var feedback = FeedbackService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(session)
                .environmentObject(location)
                .environmentObject(merchants)
                .environmentObject(rewards)
                .environmentObject(redemptions)
                .environmentObject(favorites)
                .environmentObject(owners)
                .environmentObject(billing)
                .environmentObject(feedback)
                .tint(LocalsTheme.accent)
                .task {
                    auth.onSignIn = { _ in
                        Task {
                            await favorites.refresh()
                            await owners.refresh()
                        }
                    }
                    auth.onSignOut = {
                        Task { @MainActor in
                            favorites.objectWillChange.send()
                        }
                    }
                    await auth.bootstrap()
                    if auth.currentUser != nil {
                        await favorites.refresh()
                        await owners.refresh()
                    }
                    location.requestPermissionIfNeeded()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    /// locals://m/<slug> opens a merchant detail by slug.
    /// locals://auth/callback completes the magic-link sign-in (Supabase
    /// handles the session swap automatically when AppDelegate hands the
    /// URL to the auth client).
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "locals" else { return }
        if url.host == "m" {
            let slug = url.lastPathComponent
            guard !slug.isEmpty else { return }
            session.pendingMerchantSlug = slug
            session.activeTab = .discover
        }
        // Supabase Swift's auth client picks up the OTP callback when
        // detectSessionInUrl is on (the default).
    }
}
