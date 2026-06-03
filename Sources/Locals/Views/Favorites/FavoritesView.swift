import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favorites: FavoriteService
    @EnvironmentObject var auth: AuthService

    @State private var rows: [FavoriteWithMerchant] = []
    @State private var loading = false
    @State private var pushedSlug: String?

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
                            Button {
                                Haptics.tap()
                                pushedSlug = row.merchants?.slug
                            } label: {
                                FavoriteRowView(row: row)
                            }
                            .listRowBackground(LocalsTheme.bg)
                            .listRowSeparatorTint(LocalsTheme.borderSubtle)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await favorites.remove(row.merchant_id)
                                        await reload()
                                    }
                                } label: {
                                    Label("Remove", systemImage: "heart.slash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await reload() }
                }
            }
            .background(LocalsTheme.bg)
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
            .task { await reload() }
            .navigationDestination(isPresented: Binding(
                get: { pushedSlug != nil },
                set: { if !$0 { pushedSlug = nil } }
            )) {
                if let slug = pushedSlug { MerchantDetailView(slug: slug) }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: DesignTokens.Space.sm) {
            Text("Nothing saved yet")
                .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
            Text("Tap the heart on a business to keep it here.")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
        }
        .padding(DesignTokens.Space.xl)
    }

    private var signInWall: some View {
        VStack(spacing: DesignTokens.Space.md) {
            Text("Sign in to keep favourites.")
                .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
            Text("Save businesses and use rewards from one tap.")
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
        do { rows = try await favorites.list() } catch { }
    }
}

struct FavoriteRowView: View {
    let row: FavoriteWithMerchant
    var body: some View {
        HStack(spacing: DesignTokens.Space.md) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(MerchantTheme.background(for: row.merchants?.theme_color))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .strokeBorder(LocalsTheme.borderSubtle, lineWidth: 1)
                )
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.merchants?.name ?? "")
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                Text(row.merchants?.category?.capitalized ?? "")
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
                if let addr = row.merchants?.address {
                    Text(addr)
                        .font(LocalsTheme.body(DesignTokens.Size.xs))
                        .foregroundStyle(LocalsTheme.fgMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(LocalsTheme.fgMuted)
        }
        .padding(.vertical, DesignTokens.Space.xs)
    }
}
