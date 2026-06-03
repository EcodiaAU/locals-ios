import SwiftUI
import Foundation

/// Local-only favorites. Customer side is fully anonymous - no auth, no
/// Supabase. Favorites live in UserDefaults as a JSON-encoded array of
/// snapshots, so the Saved tab can render names + categories + theme
/// colours offline without round-tripping for each row.
///
/// If/when accounts return (or we ship iCloud sync via NSUbiquitousKVStore),
/// the migration is one-way upload: read this Set, mirror to the table,
/// keep this as the source of truth.
@MainActor
final class FavoriteService: ObservableObject {
    @Published private(set) var snapshots: [LocalFavorite] = []
    private let storageKey = "locals.favorites.v1"

    init() {
        load()
    }

    var ids: Set<UUID> { Set(snapshots.map(\.id)) }
    var sortedByRecent: [LocalFavorite] {
        snapshots.sorted { ($0.saved_at) > ($1.saved_at) }
    }

    func isFavorite(_ merchantId: UUID) -> Bool { ids.contains(merchantId) }

    func toggle(from merchant: MerchantNear) {
        if isFavorite(merchant.id) { remove(merchant.id) }
        else { add(LocalFavorite(from: merchant)) }
    }

    func toggle(from merchant: Merchant) {
        if isFavorite(merchant.id) { remove(merchant.id) }
        else { add(LocalFavorite(from: merchant)) }
    }

    func add(_ fav: LocalFavorite) {
        if !ids.contains(fav.id) {
            snapshots.append(fav)
            save()
        }
    }

    func remove(_ merchantId: UUID) {
        snapshots.removeAll { $0.id == merchantId }
        save()
    }

    // MARK: - persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LocalFavorite].self, from: data) else {
            snapshots = []
            return
        }
        snapshots = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

/// One row in the local Saved list. Snapshotted at save-time so the list
/// renders without a network call. Slug stays canonical for opening
/// detail; if the merchant has renamed since, detail re-fetches.
struct LocalFavorite: Codable, Identifiable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let category: String?
    let address: String?
    let theme_color: String?
    let theme_font: String?
    let saved_at: Date

    init(from m: MerchantNear) {
        self.id = m.id
        self.slug = m.slug
        self.name = m.name
        self.category = m.category
        self.address = m.address
        self.theme_color = m.theme_color
        self.theme_font = m.theme_font
        self.saved_at = Date()
    }

    init(from m: Merchant) {
        self.id = m.id
        self.slug = m.slug
        self.name = m.name
        self.category = m.category
        self.address = m.address
        self.theme_color = m.theme_color
        self.theme_font = m.theme_font
        self.saved_at = Date()
    }
}
