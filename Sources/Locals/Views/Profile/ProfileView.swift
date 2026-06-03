import SwiftUI

/// Customer-side "Me" tab. Anonymous by default - no signin wall, no
/// account record on the server side. Sign-in is only ever triggered
/// from "Add your business" (or by tapping into the Merchant tab from
/// the dashboard). Everything else is local.
struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var owners: OwnerMerchantService

    @State private var showSignIn = false
    @State private var showSettings = false
    @State private var showFeedback = false
    @State private var showSignUpMerchant = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                    header
                    listBusinessBlock
                    tilesBlock
                    if let email = auth.currentUser?.email {
                        signOutBlock(email: email)
                    }
                }
                .padding(DesignTokens.Space.lg)
            }
            .background(LocalsTheme.bg)
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSignIn) { SignInView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showFeedback) { FeedbackSheet() }
            .sheet(isPresented: $showSignUpMerchant) { CreateMerchantView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Locals")
            Text("Browse anonymously.\nList a business to sign in.")
                .font(LocalsTheme.display(DesignTokens.Size.h2, italic: true))
                .foregroundStyle(LocalsTheme.fg)
            Text("We never ask for an account just to browse. No tracking, no ads, no inbox.")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
    }

    @ViewBuilder
    private var listBusinessBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Your business")
            if owners.hasAny {
                ForEach(owners.owned) { o in
                    Button {
                        session.activeTab = .merchant
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(o.merchants?.name ?? "Business")
                                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
                                    .foregroundStyle(LocalsTheme.fg)
                                Text(o.merchants?.status ?? "")
                                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                                    .foregroundStyle(LocalsTheme.fgMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(LocalsTheme.fgMuted)
                        }
                        .padding(DesignTokens.Space.md)
                        .background(LocalsTheme.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                if auth.currentUser == nil { showSignIn = true } else { showSignUpMerchant = true }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(owners.hasAny ? "Add another business" : "Add your business")
                        .font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
                }
                .padding(DesignTokens.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LocalsTheme.bgElevated)
                .foregroundStyle(LocalsTheme.fg)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var tilesBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "App")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Space.sm) {
                ProfileTile(title: "Map", system: "map", action: { session.activeTab = .discover })
                ProfileTile(title: "Saved", system: "heart", action: { session.activeTab = .saved })
                ProfileTile(title: "Settings", system: "slider.horizontal.3", action: { showSettings = true })
                ProfileTile(title: "Feedback", system: "envelope", action: { showFeedback = true })
            }
        }
    }

    private func signOutBlock(email: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            Text("Signed in as \(email)")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(LocalsTheme.fgMuted)
            Button {
                Task { await auth.signOut() }
            } label: {
                Text("Sign out")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.localsSecondary)
        }
    }
}

struct ProfileTile: View {
    let title: String
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                Image(systemName: system)
                    .font(.title2)
                    .foregroundStyle(LocalsTheme.accent)
                Text(title)
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                    .foregroundStyle(LocalsTheme.fg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Space.lg)
            .background(LocalsTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
