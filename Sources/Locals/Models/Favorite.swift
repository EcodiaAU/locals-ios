import Foundation

struct Favorite: Codable, Hashable {
    let user_id: UUID
    let merchant_id: UUID
    let created_at: Date?
}

// PostgREST nested-select shape for the favorites list view, so we can show
// merchant name + category + address without a second roundtrip.
struct FavoriteWithMerchant: Codable, Identifiable, Hashable {
    let merchant_id: UUID
    let created_at: Date?
    let merchants: Inner?

    struct Inner: Codable, Hashable {
        let slug: String
        let name: String
        let category: String?
        let address: String?
        let theme_color: String?
        let theme_font: String?
        let hero_image_path: String?
    }

    var id: UUID { merchant_id }
}
