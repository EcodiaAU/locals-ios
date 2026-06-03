import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var owners: OwnerMerchantService

    @State private var showSignIn = false
    @State private var showRedemptions = false
    @State private var showSettings = false
    @State private var showFeedback = false
    @State private var showSignUpMerchant = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                    header
                    yourBusinessBlock
                    yoursBlock
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
            .sheet(isPresented: $showRedemptions) { MyRedemptionsView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showFeedback) { FeedbackSheet() }
            .sheet(isPresented: $showSignUpMerchant) { CreateMerchantView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            if let email = auth.currentUser?.email {
                Eyebrow(text: "Signed in as")
                Text(email)
                    .font(LocalsTheme.body(DesignTokens.Size.lg, weight: .medium))
                    .foregroundStyle(LocalsTheme.fg)
            } else {
                Text("Sign in,\nuse rewards.")
                    .font(LocalsTheme.display(DesignTokens.Size.h2, italic: true))
                    .foregroundStyle(LocalsTheme.fg)
                Button {
                    showSignIn = true
                } label: {
                    Text("Sign in")
                }
                .buttonStyle(.localsPrimary)
                .padding(.top, DesignTokens.Space.md)
            }
        }
    }

    @ViewBuilder
    private var yourBusinessBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Your business")
            if owners.hasAny {
                ForEach(owners.owned) { o in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(o.merchants?.name ?? "Business")
                                .font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
                            Text(o.merchants?.status ?? "")
                                .font(LocalsTheme.body(DesignTokens.Size.xs))
                                .foregroundStyle(LocalsTheme.fgMuted)
                        }
                        Spacer()
                        Button {
                            session.activeTab = .merchant
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(DesignTokens.Space.md)
                    .background(LocalsTheme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
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

    private var yoursBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Yours")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Space.sm) {
                ProfileTile(title: "Map", system: "map", action: { session.activeTab = .discover })
                ProfileTile(title: "Codes", system: "qrcode", action: {
                    if auth.currentUser == nil { showSignIn = true } else { showRedemptions = true }
                })
                ProfileTile(title: "Saved", system: "heart", action: { session.activeTab = .saved })
                ProfileTile(title: "Settings", system: "slider.horizontal.3", action: { showSettings = true })
            }
            Button {
                showFeedback = true
            } label: {
                HStack {
                    Image(systemName: "envelope")
                    Text("Send feedback")
                        .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
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

    private func signOutBlock(email: String) -> some View {
        Button {
            Task { await auth.signOut() }
        } label: {
            Text("Sign out")
                .foregroundStyle(.red)
        }
        .buttonStyle(.localsSecondary)
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
