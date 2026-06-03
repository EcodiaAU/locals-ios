import Foundation
import Supabase

@MainActor
final class FavoriteService: ObservableObject {
    private let client: SupabaseClient
    @Published private(set) var ids: Set<UUID> = []

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    /// Refresh the local Set on sign-in. RLS gates to the caller, so this
    /// just selects merchant_id from favorites.
    func refresh() async {
        struct Row: Codable { let merchant_id: UUID }
        do {
            let rows: [Row] = try await client
                .from("favorites")
                .select("merchant_id")
                .execute()
                .value
            ids = Set(rows.map(\.merchant_id))
        } catch {
            // Silent - probably signed out. Empty Set is the right state.
            ids = []
        }
    }

    func isFavorite(_ merchantId: UUID) -> Bool { ids.contains(merchantId) }

    func toggle(_ merchantId: UUID) async {
        if ids.contains(merchantId) {
            await remove(merchantId)
        } else {
            await add(merchantId)
        }
    }

    func add(_ merchantId: UUID) async {
        struct Row: Encodable { let merchant_id: UUID }
        ids.insert(merchantId) // optimistic
        do {
            try await client
                .from("favorites")
                .upsert(Row(merchant_id: merchantId), onConflict: "user_id,merchant_id")
                .execute()
        } catch {
            ids.remove(merchantId) // rollback
        }
    }

    func remove(_ merchantId: UUID) async {
        ids.remove(merchantId)
        do {
            try await client
                .from("favorites")
                .delete()
                .eq("merchant_id", value: merchantId.uuidString)
                .execute()
        } catch {
            ids.insert(merchantId)
        }
    }

    func list() async throws -> [FavoriteWithMerchant] {
        let rows: [FavoriteWithMerchant] = try await client
            .from("favorites")
            .select("""
                merchant_id, created_at,
                merchants(slug, name, category, address, theme_color, theme_font, hero_image_path)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }
}
