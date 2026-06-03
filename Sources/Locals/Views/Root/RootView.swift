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
        .toolbarBackground(LocalsTheme.bg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
