import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var owners: OwnerMerchantService

    var body: some View {
        Group {
            if !session.hasOnboarded {
                OnboardingView()
            } else {
                tabs
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.base), value: session.hasOnboarded)
    }

    // Default iOS 26 TabView, native floating pill, no appearance overrides.
    // Matches glovebox-ios RootView pattern (2026-06-12). The Discover sheet
    // reads geo.safeAreaInsets.bottom to know how high the pill sits and
    // pads its content above it; the sheet's material bleeds past the pill
    // to the screen edge via .ignoresSafeArea(.container, edges: .bottom).
    private var tabs: some View {
        TabView(selection: $session.activeTab) {
            DiscoverView()
                .tabItem { Label("Near you", systemImage: "mappin.and.ellipse") }
                .tag(RootTab.discover)

            FavoritesView()
                .tabItem { Label("Saved", systemImage: "heart") }
                .tag(RootTab.saved)

            ProfileView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
                .tag(RootTab.me)

            if owners.hasAny {
                MerchantDashboardView()
                    .tabItem { Label("My business", systemImage: "storefront") }
                    .tag(RootTab.merchant)
            }
        }
        .tint(LocalsTheme.fg)  // auto-flips: ink in light, cream in dark — selected-tab tint stays visible in both
    }
}
