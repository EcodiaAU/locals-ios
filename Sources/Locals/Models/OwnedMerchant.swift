import Foundation

// A row from merchant_users joined with merchants - the merchants the
// current user owns or works at. Drives the merchant-admin tab.
struct OwnedMerchant: Codable, Identifiable, Hashable {
    let merchant_id: UUID
    let role: String
    let merchants: Inner?

    struct Inner: Codable, Hashable {
        let slug: String
        let name: String
        let status: String?
        let theme_color: String?
        let theme_font: String?
    }

    var id: UUID { merchant_id }
    var resolvedRole: MerchantRole {
        MerchantRole(rawValue: role) ?? .staff
    }
}

// Returned by claim_merchant / create_merchant RPC.
struct ClaimedMerchant: Codable, Hashable {
    let merchant_id: UUID
    let role: String
}

struct CreatedMerchant: Codable, Hashable {
    let id: UUID
    let slug: String
}

// merchant_subscriptions row - billing state for the merchant.
struct MerchantSubscription: Codable, Hashable {
    let merchant_id: UUID
    let stripe_customer_id: String?
    let stripe_subscription_id: String?
    let amount_cents_monthly: Int?
    let currency: String?
    let status: String?
    let current_period_end: Date?
    let cancel_at: Date?

    var isActive: Bool { status == "active" }
    var amountDollars: Double { Double(amount_cents_monthly ?? 0) / 100 }
}
