import SwiftUI

/// Customer-side "Me" tab. Anonymous by default - no signin wall, no
/// account record on the server side. Sign-in is only ever triggered
/// from "List your business" (or by tapping into the Merchant tab from
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
                VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                    listBusinessBlock
                    if let email = auth.currentUser?.email {
                        signOutBlock(email: email)
                    }
                    secondaryLinks
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

    @ViewBuilder
    private var listBusinessBlock: some View {
        if owners.hasAny {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
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
                Button {
                    if auth.currentUser == nil { showSignIn = true } else { showSignUpMerchant = true }
                } label: {
                    HStack(spacing: DesignTokens.Space.sm) {
                        Image(systemName: "plus")
                        Text("Add another business")
                    }
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
                    .padding(DesignTokens.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(LocalsTheme.fgMuted)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                Haptics.tap()
                if auth.currentUser == nil { showSignIn = true } else { showSignUpMerchant = true }
            } label: {
                HStack {
                    Image(systemName: "storefront")
                    Text("List your business")
                        .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(LocalsTheme.onAccent.opacity(0.7))
                }
                .padding(DesignTokens.Space.lg)
                .foregroundStyle(LocalsTheme.onAccent)
                .background(LocalsTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var secondaryLinks: some View {
        VStack(spacing: 0) {
            ProfileLinkRow(title: "Settings", system: "slider.horizontal.3") {
                showSettings = true
            }
            Divider().background(LocalsTheme.borderSubtle)
            ProfileLinkRow(title: "Send feedback", system: "envelope") {
                showFeedback = true
            }
        }
        .background(LocalsTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
        .padding(.top, DesignTokens.Space.lg)
    }

    private func signOutBlock(email: String) -> some View {
        HStack {
            Text("Signed in as \(email)")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(LocalsTheme.fgMuted)
            Spacer()
            Button("Sign out") {
                Task { await auth.signOut() }
            }
            .font(LocalsTheme.body(DesignTokens.Size.xs))
            .foregroundStyle(.red)
        }
    }
}

struct ProfileLinkRow: View {
    let title: String
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: DesignTokens.Space.md) {
                Image(systemName: system)
                    .font(.body)
                    .foregroundStyle(LocalsTheme.fgMuted)
                    .frame(width: 24)
                Text(title)
                    .font(LocalsTheme.body(DesignTokens.Size.base))
                    .foregroundStyle(LocalsTheme.fg)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            .padding(DesignTokens.Space.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
