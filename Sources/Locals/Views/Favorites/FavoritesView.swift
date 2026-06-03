import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favorites: FavoriteService
    @State private var pushedSlug: String?

    var body: some View {
        NavigationStack {
            Group {
                if favorites.snapshots.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(favorites.sortedByRecent) { fav in
                            Button {
                                Haptics.tap()
                                pushedSlug = fav.slug
                            } label: {
                                FavoriteRowView(fav: fav)
                            }
                            .listRowBackground(LocalsTheme.bg)
                            .listRowSeparatorTint(LocalsTheme.borderSubtle)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    favorites.remove(fav.id)
                                } label: {
                                    Label("Remove", systemImage: "heart.slash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LocalsTheme.bg)
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
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
}

struct FavoriteRowView: View {
    let fav: LocalFavorite
    var body: some View {
        HStack(spacing: DesignTokens.Space.md) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(MerchantTheme.background(for: fav.theme_color))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .strokeBorder(LocalsTheme.borderSubtle, lineWidth: 1)
                )
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name)
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                Text(fav.category?.capitalized ?? "")
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
                if let addr = fav.address {
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
