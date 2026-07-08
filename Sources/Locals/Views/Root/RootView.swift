import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var owners: OwnerMerchantService
    @EnvironmentObject var purchases: FriendPurchases

    /// Presents the Friend-powered Local Guide (Friend-IAP wave 3): connect ->
    /// paywall -> chat, gated on the `friend` entitlement + a linked Friend.
    @State private var showGuide = false

    #if DEBUG
    /// DEBUG-only: when launched with `-rcPaywallDemo`, present the native paywall
    /// directly (bypassing the connect gate) so the offering-fetch + native
    /// purchase sheet can be exercised on the simulator under a StoreKit
    /// configuration without a full Friend OIDC login. Mirrors glovebox's
    /// `?paywall=1` dev shortcut. Never compiled into a release build.
    @State private var showPaywallDemo = CommandLine.arguments.contains("-rcPaywallDemo")
    #endif

    var body: some View {
        Group {
            if !session.hasOnboarded {
                OnboardingView()
            } else {
                tabs
                    .overlay(alignment: .bottomTrailing) { guideFab }
                    .sheet(isPresented: $showGuide) { LocalGuideView() }
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.base), value: session.hasOnboarded)
        #if DEBUG
        .sheet(isPresented: $showPaywallDemo) {
            NavigationStack {
                PaywallView()
                    .navigationTitle("Paywall (demo)")
                    .navigationBarTitleDisplayMode(.inline)
                    .task { await purchases.loadOffering() }
            }
        }
        #endif
    }

    // The floating guide button - the single entry point to the Local Guide.
    // A subtle "unlock" dot rides the corner until the person is entitled, so
    // the paid perk advertises itself without a nag. Sits above the tab pill.
    private var guideFab: some View {
        Button {
            showGuide = true
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LocalsTheme.onAccent)
                .frame(width: 56, height: 56)
                .background(LocalsTheme.accent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                .overlay(alignment: .topTrailing) {
                    if !purchases.isEntitled {
                        Circle()
                            .fill(LocalsTheme.mustard)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(LocalsTheme.bg, lineWidth: 2))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .accessibilityLabel("Local guide")
        .padding(.trailing, DesignTokens.Space.lg)
        .padding(.bottom, DesignTokens.Space._12 + DesignTokens.Space.xl)
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
        .tint(LocalsTheme.fg)  // auto-flips: ink in light, cream in dark - selected-tab tint stays visible in both
    }
}
