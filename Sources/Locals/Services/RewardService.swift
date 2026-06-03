import Foundation
import Supabase

@MainActor
final class RewardService: ObservableObject {
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    /// All currently-live rewards for a merchant, ordered most-recent first.
    /// Anonymous users see them too (RLS gates on is_active + merchant
    /// active), so this works pre-sign-in for browsing.
    func live(merchantId: UUID) async throws -> [Reward] {
        let rows: [Reward] = try await client
            .from("rewards")
            .select("""
                id, merchant_id, title, description, reward_type, value_pct,
                value_amount_cents, max_redemptions_per_user, max_total_redemptions,
                starts_at, ends_at, is_active, is_first_visit, valid_from,
                valid_until, created_at
            """)
            .eq("merchant_id", value: merchantId.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    /// All rewards for the merchant admin (active + paused + scheduled).
    func all(merchantId: UUID) async throws -> [Reward] {
        let rows: [Reward] = try await client
            .from("rewards")
            .select("""
                id, merchant_id, title, description, reward_type, value_pct,
                value_amount_cents, max_redemptions_per_user, max_total_redemptions,
                starts_at, ends_at, is_active, is_first_visit, valid_from,
                valid_until, created_at
            """)
            .eq("merchant_id", value: merchantId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    struct Draft: Encodable {
        let merchant_id: UUID
        let title: String
        let description: String?
        let reward_type: String
        let value_pct: Double?
        let value_amount_cents: Int?
        let max_redemptions_per_user: Int?
        let is_active: Bool
        let is_first_visit: Bool
        let valid_until: Date?
    }

    func create(_ draft: Draft) async throws -> Reward {
        let inserted: Reward = try await client
            .from("rewards")
            .insert(draft)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func setActive(_ rewardId: UUID, active: Bool) async throws {
        struct Patch: Encodable { let is_active: Bool }
        try await client
            .from("rewards")
            .update(Patch(is_active: active))
            .eq("id", value: rewardId.uuidString)
            .execute()
    }

    func delete(_ rewardId: UUID) async throws {
        try await client
            .from("rewards")
            .delete()
            .eq("id", value: rewardId.uuidString)
            .execute()
    }
}
