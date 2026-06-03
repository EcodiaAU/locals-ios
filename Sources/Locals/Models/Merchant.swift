import Foundation
import CoreLocation

// Hand-rolled Codable models matching the locals-shared schema. Generated
// types via the Supabase CLI would be a maintenance win once Postgres type
// gen for Swift exists; until then these are tracked by hand alongside
// each migration. See ../locals-shared/supabase/migrations for the canonical
// shape.

struct Merchant: Codable, Identifiable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let category: String
    let story: String?
    let address: String?
    let sustainability_tags: [String]?
    let status: String?
    let hero_image_path: String?
    let owner_note: String?
    let owner_note_at: Date?
    let theme_color: String?
    let theme_font: String?
    let abn: String?
    let abn_verified_at: Date?
    let abn_legal_name: String?
    let hours: [String: String]?
    let contact: ContactInfo?
    let created_at: Date?
    let updated_at: Date?

    struct ContactInfo: Codable, Hashable {
        let phone: String?
        let email: String?
        let instagram: String?
        let website: String?
    }

    var resolvedStatus: MerchantStatus {
        MerchantStatus(rawValue: status ?? "active") ?? .active
    }

    var resolvedCategory: MerchantCategory { .resolve(category) }

    var tags: [SustainabilityTag] {
        (sustainability_tags ?? []).compactMap { SustainabilityTag(rawValue: $0) }
    }
}

// The merchants_near RPC return shape (see migration 0008). One row per
// nearby merchant, joined with the live crowd count and hero photo path.
struct MerchantNear: Codable, Identifiable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let category: String
    let story: String?
    let address: String?
    let sustainability_tags: [String]?
    let distance_m: Double
    let owner_note: String?
    let owner_note_at: Date?
    let crowd_last_hour: Int?
    let abn_verified: Bool?
    let theme_color: String?
    let theme_font: String?
    let hero_photo_path: String?

    var distanceLabel: String {
        if distance_m < 950 { return "\(Int((distance_m / 10).rounded()) * 10) m" }
        let km = distance_m / 1000
        return String(format: "%.1f km", km)
    }

    var resolvedCategory: MerchantCategory { .resolve(category) }
    var tags: [SustainabilityTag] {
        (sustainability_tags ?? []).compactMap { SustainabilityTag(rawValue: $0) }
    }
}

// Optional - the geo field on `merchants` is a PostGIS geography(point).
// We do not read it on the client: the lat/lng come back through the
// merchants_near RPC as `distance_m` from the user. The merchant detail
// view never needs the raw point; map pins fetch from the RPC.

struct MerchantPhoto: Codable, Identifiable, Hashable {
    let id: UUID
    let merchant_id: UUID
    let storage_path: String
    let caption: String?
    let sort_order: Int?
    let created_at: Date?
}
