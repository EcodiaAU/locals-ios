import Foundation
import Supabase

@MainActor
final class OwnerMerchantService: ObservableObject {
    private let client: SupabaseClient
    @Published private(set) var owned: [OwnedMerchant] = []

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    /// Merchants the signed-in user is owner / staff on. Drives whether the
    /// Merchant tab appears in the root TabView.
    func refresh() async {
        do {
            let rows: [OwnedMerchant] = try await client
                .from("merchant_users")
                .select("""
                    merchant_id, role,
                    merchants(slug, name, status, theme_color, theme_font)
                """)
                .order("created_at", ascending: true)
                .execute()
                .value
            owned = rows
        } catch {
            owned = []
        }
    }

    var hasAny: Bool { !owned.isEmpty }

    /// Create a new merchant + claim ownership in a single RPC.
    func create(
        name: String,
        slug: String,
        category: String,
        lat: Double,
        lng: Double,
        story: String?,
        address: String?,
        tags: [SustainabilityTag]
    ) async throws -> CreatedMerchant {
        struct Params: Encodable {
            let p_name: String
            let p_slug: String
            let p_category: String
            let p_lat: Double
            let p_lng: Double
            let p_story: String?
            let p_address: String?
            let p_sustainability_tags: [String]
        }
        let rows: [CreatedMerchant] = try await client
            .rpc("create_merchant", params: Params(
                p_name: name,
                p_slug: slug,
                p_category: category,
                p_lat: lat,
                p_lng: lng,
                p_story: story,
                p_address: address,
                p_sustainability_tags: tags.map(\.rawValue)
            ))
            .execute()
            .value
        guard let first = rows.first else {
            throw OwnerMerchantError.createFailed
        }
        await refresh()
        return first
    }

    /// Update merchant basics. The MerchantService owns this surface because
    /// editing is conceptually one document, but routing it through the
    /// owner service keeps the admin-only mutations in one place.
    func updateBasics(
        merchantId: UUID,
        name: String?,
        story: String?,
        address: String?,
        category: String?,
        tags: [SustainabilityTag]?
    ) async throws {
        struct Patch: Encodable {
            let name: String?
            let story: String?
            let address: String?
            let category: String?
            let sustainability_tags: [String]?
        }
        try await client
            .from("merchants")
            .update(Patch(
                name: name,
                story: story,
                address: address,
                category: category,
                sustainability_tags: tags?.map(\.rawValue)
            ))
            .eq("id", value: merchantId.uuidString)
            .execute()
    }

    func updateTheme(merchantId: UUID, color: String, font: String) async throws {
        struct Patch: Encodable {
            let theme_color: String
            let theme_font: String
        }
        try await client
            .from("merchants")
            .update(Patch(theme_color: color, theme_font: font))
            .eq("id", value: merchantId.uuidString)
            .execute()
    }

    func setOwnerNote(merchantId: UUID, note: String) async throws {
        struct Params: Encodable {
            let p_merchant_id: UUID
            let p_note: String
        }
        try await client
            .rpc("set_owner_note", params: Params(p_merchant_id: merchantId, p_note: note))
            .execute()
    }

    func setStatus(merchantId: UUID, status: MerchantStatus) async throws {
        struct Patch: Encodable { let status: String }
        try await client
            .from("merchants")
            .update(Patch(status: status.rawValue))
            .eq("id", value: merchantId.uuidString)
            .execute()
    }

    // MARK: - Subscription

    func subscription(merchantId: UUID) async throws -> MerchantSubscription? {
        let rows: [MerchantSubscription] = try await client
            .from("merchant_subscriptions")
            .select("merchant_id, stripe_customer_id, stripe_subscription_id, amount_cents_monthly, currency, status, current_period_end, cancel_at")
            .eq("merchant_id", value: merchantId.uuidString)
            .execute()
            .value
        return rows.first
    }
}

enum OwnerMerchantError: LocalizedError {
    case createFailed
    var errorDescription: String? {
        switch self {
        case .createFailed: return "Could not create your business. Try a different slug or try again."
        }
    }
}
