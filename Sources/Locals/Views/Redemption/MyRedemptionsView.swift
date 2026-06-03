import SwiftUI

struct MyRedemptionsView: View {
    @EnvironmentObject var redemptions: RedemptionService
    @EnvironmentObject var auth: AuthService

    @State private var rows: [RedemptionRow] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Group {
                if auth.currentUser == nil {
                    signInWall
                } else if loading && rows.isEmpty {
                    ProgressView()
                } else if rows.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(rows) { row in
                            RedemptionRowView(row: row)
                                .listRowBackground(LocalsTheme.bg)
                                .listRowSeparatorTint(LocalsTheme.borderSubtle)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await reload() }
                }
            }
            .background(LocalsTheme.bg)
            .navigationTitle("Your codes")
            .navigationBarTitleDisplayMode(.large)
            .task { await reload() }
        }
    }

    private var signInWall: some View {
        VStack(spacing: DesignTokens.Space.md) {
            Text("Sign in to see your codes.")
                .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
            Text("Codes you've redeemed stay here.")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
        .padding(DesignTokens.Space.xl)
    }

    private var empty: some View {
        VStack(spacing: DesignTokens.Space.sm) {
            Text("No codes yet")
                .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
            Text("Find a business near you and grab one.")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
        .padding(DesignTokens.Space.xl)
    }

    @MainActor
    private func reload() async {
        guard auth.currentUser != nil else { return }
        loading = true
        defer { loading = false }
        do {
            rows = try await redemptions.mine(limit: 50)
        } catch {
            // empty state already covers the wireframe
        }
    }
}

struct RedemptionRowView: View {
    let row: RedemptionRow

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.merchantName)
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                Text(row.rewardTitle)
                    .font(LocalsTheme.body(DesignTokens.Size.sm))
                    .foregroundStyle(LocalsTheme.fgMuted)
                Text(row.redeemed_at, format: .relative(presentation: .named))
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, DesignTokens.Space.sm)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch row.status {
        case .active:
            Text("Active")
                .font(LocalsTheme.body(DesignTokens.Size.xs, weight: .semibold))
                .padding(.horizontal, DesignTokens.Space.sm)
                .padding(.vertical, 4)
                .background(LocalsTheme.accent)
                .foregroundStyle(LocalsTheme.onAccent)
                .clipShape(Capsule())
        case .consumed:
            Text("Used")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(LocalsTheme.fgMuted)
        case .expired:
            Text("Expired")
                .font(LocalsTheme.body(DesignTokens.Size.xs))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
    }
}
