import SwiftUI

@main
struct LocalsApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var session = AppSession()
    @StateObject private var location = LocationManager()
    @StateObject private var merchants = MerchantService()
    @StateObject private var rewards = RewardService()
    @StateObject private var favorites = FavoriteService()
    @StateObject private var owners = OwnerMerchantService()
    @StateObject private var billing = BillingService()
    @StateObject private var feedback = FeedbackService()
    @StateObject private var purchases = FriendPurchases()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(session)
                .environmentObject(location)
                .environmentObject(merchants)
                .environmentObject(rewards)
                .environmentObject(favorites)
                .environmentObject(owners)
                .environmentObject(billing)
                .environmentObject(feedback)
                .environmentObject(purchases)
                .tint(LocalsTheme.accent)
                .task {
                    // Auth bootstrap is now merchant-only. The customer side
                    // is anonymous - no signin wall on browse, favorites, or
                    // detail. Sign-in is only invoked when the user taps
                    // "Add your business" or opens the Merchant tab.
                    auth.onSignIn = { _ in
                        Task {
                            await owners.refresh()
                            // Re-key RevenueCat to the Friend account id whenever a
                            // sign-in lands (Friend-IAP wave 3). friend_id populates
                            // in app_metadata after a Connect-your-Friend login.
                            await purchases.logIn(friendID: auth.friendID, localUserID: auth.localUserID)
                            await purchases.refresh()
                        }
                    }
                    // Configure RevenueCat with the platform public key (no-op if
                    // the key is not baked). Identify + refresh entitlement from the
                    // restored session so the Local Guide gate is correct on launch.
                    purchases.configure(apiKey: LocalsConfig.revenueCatIOSKey)
                    await auth.bootstrap()
                    if auth.currentUser != nil {
                        await owners.refresh()
                        await purchases.logIn(friendID: auth.friendID, localUserID: auth.localUserID)
                    }
                    await purchases.refresh()
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
