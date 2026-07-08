import SwiftUI

/// The native paywall for the Friend "A little" subscription (Friend-IAP wave 3).
/// Shown when a Friend-connected Locals user is not yet entitled. Buys the
/// RevenueCat `default` offering's `$rc_monthly` package via the native system
/// purchase sheet - never a web checkout link (upgrades to higher tiers happen
/// on Friend WEB only, and this never touches Stripe). Copy carries the fixed
/// A$19.99/mo line and the App Store / Google Play auto-renewal disclosure, and
/// never uses "lifetime/forever" language.
struct PaywallView: View {
    @EnvironmentObject var purchases: FriendPurchases
    @State private var busy = false
    @State private var restoring = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Space.xl) {
                VStack(spacing: DesignTokens.Space.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(LocalsTheme.accent)
                    Text("Your local guide, powered by your Friend")
                        .font(LocalsTheme.display(28))
                        .foregroundStyle(LocalsTheme.fg)
                        .multilineTextAlignment(.center)
                    Text("Ask it anything about where you are - a good local coffee, dinner tonight, somewhere for the kids - and it answers from real locally-owned places, grounded in what your Friend already knows about you.")
                        .font(LocalsTheme.serif(17))
                        .foregroundStyle(LocalsTheme.fgMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignTokens.Space.xl)

                VStack(spacing: DesignTokens.Space.xs) {
                    Text(purchases.displayPrice)
                        .font(LocalsTheme.display(34))
                        .foregroundStyle(LocalsTheme.fg)
                    Text("per month. cancel anytime.")
                        .font(LocalsTheme.serif(16))
                        .foregroundStyle(LocalsTheme.fgMuted)
                }
                .padding(.vertical, DesignTokens.Space.md)

                VStack(spacing: DesignTokens.Space.md) {
                    Button {
                        Task { await subscribe() }
                    } label: {
                        HStack(spacing: DesignTokens.Space.sm) {
                            if busy { ProgressView().tint(LocalsTheme.onAccent) }
                            Text(busy ? "Opening…" : "Subscribe")
                        }
                    }
                    .buttonStyle(.localsPrimary)
                    .disabled(busy || restoring)

                    Button {
                        Task { await restore() }
                    } label: {
                        Text(restoring ? "Restoring…" : "Restore purchase")
                    }
                    .buttonStyle(.localsSecondary)
                    .disabled(busy || restoring)
                }

                if let error = purchases.lastError {
                    Text(error)
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Text(FriendPlan.renewalDisclosure)
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgTrace)
                    .multilineTextAlignment(.center)
                    .padding(.top, DesignTokens.Space.sm)
            }
            .padding(DesignTokens.Space.xl)
        }
    }

    private func subscribe() async {
        busy = true; purchases.lastError = nil
        defer { busy = false }
        _ = await purchases.purchase()
    }

    private func restore() async {
        restoring = true; purchases.lastError = nil
        defer { restoring = false }
        _ = await purchases.restore()
    }
}
