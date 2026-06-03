import SwiftUI

struct MerchantDashboardView: View {
    @EnvironmentObject var owners: OwnerMerchantService
    @EnvironmentObject var rewards: RewardService
    @State private var selected: OwnedMerchant?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                    header
                    merchantPicker
                    if let m = effectiveSelection {
                        actionsRow(for: m)
                        rewardsAdminLink(for: m)
                        scanCodeLink(for: m)
                        billingLink(for: m)
                    }
                }
                .padding(DesignTokens.Space.lg)
            }
            .background(LocalsTheme.bg)
            .navigationTitle("My business")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await owners.refresh() }
        }
    }

    private var effectiveSelection: OwnedMerchant? {
        selected ?? owners.owned.first
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: "Welcome back")
            Text("Run your business.")
                .font(LocalsTheme.display(DesignTokens.Size.h2, italic: true))
                .foregroundStyle(LocalsTheme.fg)
        }
    }

    @ViewBuilder
    private var merchantPicker: some View {
        if owners.owned.count > 1 {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                Eyebrow(text: "Acting on")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Space.sm) {
                        ForEach(owners.owned) { o in
                            Button {
                                selected = o
                            } label: {
                                Text(o.merchants?.name ?? "")
                                    .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
                                    .padding(.horizontal, DesignTokens.Space.lg)
                                    .padding(.vertical, DesignTokens.Space.sm)
                                    .background(o == effectiveSelection ? LocalsTheme.fg : LocalsTheme.bgElevated)
                                    .foregroundStyle(o == effectiveSelection ? LocalsTheme.bg : LocalsTheme.fg)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private func actionsRow(for m: OwnedMerchant) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Eyebrow(text: m.merchants?.name ?? "")
            HStack(spacing: DesignTokens.Space.sm) {
                NavigationLink {
                    MerchantEditView(merchantId: m.merchant_id)
                } label: {
                    DashboardTile(title: "Edit", system: "pencil")
                }
                NavigationLink {
                    if let slug = m.merchants?.slug {
                        MerchantDetailView(slug: slug)
                    }
                } label: {
                    DashboardTile(title: "Preview", system: "eye")
                }
            }
        }
    }

    private func rewardsAdminLink(for m: OwnedMerchant) -> some View {
        NavigationLink {
            RewardsAdminView(merchantId: m.merchant_id)
        } label: {
            BigActionRow(title: "Rewards",
                         subtitle: "Add or change what customers get",
                         system: "gift")
        }
    }

    private func scanCodeLink(for m: OwnedMerchant) -> some View {
        NavigationLink {
            ConsumeCodeView(merchantId: m.merchant_id)
        } label: {
            BigActionRow(title: "Use a code",
                         subtitle: "Type the customer's 6-character code",
                         system: "qrcode.viewfinder")
        }
    }

    private func billingLink(for m: OwnedMerchant) -> some View {
        NavigationLink {
            BillingView(merchantId: m.merchant_id)
        } label: {
            BigActionRow(title: "Billing",
                         subtitle: "Pay what you want",
                         system: "creditcard")
        }
    }
}

struct DashboardTile: View {
    let title: String
    let system: String
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
            Image(systemName: system)
                .font(.title3)
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
}

struct BigActionRow: View {
    let title: String
    let subtitle: String
    let system: String
    var body: some View {
        HStack(spacing: DesignTokens.Space.lg) {
            Image(systemName: system)
                .font(.title2)
                .foregroundStyle(LocalsTheme.accent)
                .frame(width: 44, height: 44)
                .background(LocalsTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LocalsTheme.body(DesignTokens.Size.lg, weight: .semibold))
                    .foregroundStyle(LocalsTheme.fg)
                Text(subtitle)
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(LocalsTheme.fgMuted)
        }
        .padding(DesignTokens.Space.lg)
        .background(LocalsTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
    }
}
