import SwiftUI

/// The Friend-powered Local Guide - the paid perk of the Friend "A little"
/// subscription on native Locals (Friend-IAP wave 3, 2026-07-08).
///
/// Gate (client-side, on the authoritative on-device RevenueCat `friend`
/// entitlement + a linked Friend):
///   1. no Friend linked   -> connect-your-Friend prompt
///   2. linked, unentitled -> the native paywall (buys the A$19.99/mo sub)
///   3. linked + entitled  -> the guide chat (posts to the `local-guide` edge fn)
///
/// Presented as a sheet from the floating guide button on Discover.
struct LocalGuideView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var purchases: FriendPurchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isFriendConnected {
                    connectPrompt
                } else if !purchases.isEntitled {
                    PaywallView()
                } else {
                    GuideChatView()
                }
            }
            .background(LocalsTheme.bg.ignoresSafeArea())
            .navigationTitle("Local guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LocalsTheme.accent)
                }
            }
        }
        .task {
            await purchases.refresh()
            await purchases.loadOffering()
        }
    }

    // MARK: - Connect prompt (no Friend linked)

    private var connectPrompt: some View {
        VStack(spacing: DesignTokens.Space.xl) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(LocalsTheme.accent)
            Text("Unlock your local guide")
                .font(LocalsTheme.display(30))
                .foregroundStyle(LocalsTheme.fg)
                .multilineTextAlignment(.center)
            Text("Connect your Ecodia Friend and it becomes your personal local guide inside Locals: it knows you, and it points you to real locally-owned places worth your money.")
                .font(LocalsTheme.serif(17))
                .foregroundStyle(LocalsTheme.fgMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Space.lg)
            Spacer()
            ConnectFriendButton()
        }
        .padding(DesignTokens.Space.xl)
    }
}

/// The Connect-your-Friend action, shared by the guide prompt. Runs the native
/// custom:friend OIDC flow already built in AuthService.
struct ConnectFriendButton: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var purchases: FriendPurchases
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: DesignTokens.Space.sm) {
            Button {
                Task { await connect() }
            } label: {
                HStack(spacing: DesignTokens.Space.sm) {
                    if busy { ProgressView().tint(LocalsTheme.onAccent) }
                    Text(busy ? "Connecting…" : "Connect your Friend")
                }
            }
            .buttonStyle(.localsPrimary)
            .disabled(busy)

            if let error {
                Text(error)
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func connect() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await auth.signInWithFriend()
            // friend_id now lands in app_metadata; re-key RevenueCat to it.
            await purchases.logIn(friendID: auth.friendID, localUserID: auth.localUserID)
            await purchases.refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
