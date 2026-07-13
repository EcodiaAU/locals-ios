import Foundation
import Supabase

/// PostgREST + RPC calls against the `merchants` table. The Supabase Swift
/// client handles auth headers per-request via the session; anonymous reads
/// work without a token because RLS on `merchants` allows public read of
/// rows where status='active'.

@MainActor
final class MerchantService: ObservableObject {
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    // MARK: - Discover

    /// Nearby merchants via the merchants_near RPC. The DB does the haversine
    /// over PostGIS; the client just sends lat/lng/radius + maybe a category.
    func near(
        lat: Double,
        lng: Double,
        radiusKm: Double = 50,
        category: String? = nil,
        limit: Int = 100
    ) async throws -> [MerchantNear] {
        struct Params: Encodable {
            let lat: Double
            let lng: Double
            let radius_km: Double
            let category_filter: String?
            let result_limit: Int
        }
        let response: [MerchantNear] = try await client.rpc(
            "merchants_near",
            params: Params(
                lat: lat,
                lng: lng,
                radius_km: radiusKm,
                category_filter: category,
                result_limit: limit
            )
        )
        .execute()
        .value
        return response
    }

    // MARK: - Detail by slug

    /// Merchant detail by slug. Selects every column we render and pulls in
    /// the photos array via PostgREST nested select.
    func detailBySlug(_ slug: String) async throws -> Merchant {
        let result: Merchant = try await client
            .from("merchants")
            .select("""
                id, slug, name, category, story, address, sustainability_tags, status,
                hero_image_path, owner_note, owner_note_at, theme_color, theme_font,
                abn, abn_verified_at, abn_legal_name, hours, contact, created_at, updated_at
            """)
            .eq("slug", value: slug)
            .single()
            .execute()
            .value
        return result
    }

    /// Merchant detail by id.
    func detailById(_ id: UUID) async throws -> Merchant {
        let result: Merchant = try await client
            .from("merchants")
            .select("""
                id, slug, name, category, story, address, sustainability_tags, status,
                hero_image_path, owner_note, owner_note_at, theme_color, theme_font,
                abn, abn_verified_at, abn_legal_name, hours, contact, created_at, updated_at
            """)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return result
    }

    // MARK: - Coordinates

    /// A merchant's coordinates, for the "Open in Glovebox" handoff.
    ///
    /// `merchants.geo` is a PostGIS geography that PostgREST hands back as opaque
    /// EWKB, so the `Merchant` model deliberately does not carry it. The
    /// `merchant_lonlat` RPC (migration 0013, granted to `anon`) returns plain
    /// lat/lng, and locals-web already reads exactly this for the same purpose.
    ///
    /// Returns nil when the merchant has no point on file, so the caller simply
    /// does not offer directions rather than offering a route to (0, 0).
    func coordinates(slug: String) async throws -> (lat: Double, lng: Double)? {
        struct Params: Encodable { let p_slug: String }
        struct LonLat: Decodable { let lat: Double; let lng: Double }

        let rows: [LonLat] = try await client
            .rpc("merchant_lonlat", params: Params(p_slug: slug))
            .execute()
            .value

        guard let first = rows.first else { return nil }
        return (first.lat, first.lng)
    }

    // MARK: - Photos

    func photos(merchantId: UUID) async throws -> [MerchantPhoto] {
        let rows: [MerchantPhoto] = try await client
            .from("merchant_photos")
            .select("id, merchant_id, storage_path, caption, sort_order, created_at")
            .eq("merchant_id", value: merchantId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
        return rows
    }

    /// Resolve a storage_path inside the `merchant-photos` bucket to a
    /// public URL. Photos are public-bucket per the RLS policy.
    func photoURL(_ storagePath: String) -> URL? {
        try? client.storage.from("merchant-photos").getPublicURL(path: storagePath)
    }

    // MARK: - Sustainability signal

    func sustainabilitySignal(merchantId: UUID) async throws -> [SustainabilitySignal] {
        struct Params: Encodable { let p_merchant_id: UUID }
        let rows: [SustainabilitySignal] = try await client
            .rpc("sustainability_signal", params: Params(p_merchant_id: merchantId))
            .execute()
            .value
        return rows
    }

    func recordSustainabilityConfirm(merchantId: UUID, tag: String, confirmed: Bool) async throws {
        struct Row: Encodable {
            let merchant_id: UUID
            let tag: String
            let confirmed: Bool
        }
        try await client
            .from("sustainability_confirms")
            .upsert(Row(merchant_id: merchantId, tag: tag, confirmed: confirmed), onConflict: "user_id,merchant_id,tag")
            .execute()
    }

    // MARK: - Crowd pulse

    /// Fire-and-forget anonymous crowd pulse. The DB layer derives the
    /// daily salt so the same user_id in different days cannot be
    /// correlated. Client just writes "I was near this merchant".
    func writeCrowdPulse(merchantId: UUID) async throws {
        struct Row: Encodable {
            let merchant_id: UUID
            // user_hash and expires_at are filled by a default expression
            // in migration 0004; we just need to send merchant_id with
            // the user's bearer attached.
        }
        try await client
            .from("crowd_pulses")
            .insert(Row(merchant_id: merchantId))
            .execute()
    }
}
