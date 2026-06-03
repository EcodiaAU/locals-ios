import Foundation

// What the issue_redemption RPC returns (see migration 0004:280-291).
struct IssuedRedemption: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    let expires_at: Date
    let reward_title: String
    let reward_format: String

    var prettyCode: String {
        // "A1B2C3" -> "A1B 2C3" - easier for staff to read aloud.
        let s = code
        guard s.count == 6 else { return s }
        let mid = s.index(s.startIndex, offsetBy: 3)
        return "\(s[s.startIndex..<mid]) \(s[mid...])"
    }
}

// What consume_redemption returns at the merchant counter.
struct ConsumedRedemption: Codable, Hashable {
    let redeemed_at: Date
    let reward_title: String
    let reward_format: String
}

// A row from the redemptions table for the "My redemptions" list. We select
// joined columns including reward.title and merchant.name + slug.
struct RedemptionRow: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    let redeemed_at: Date
    let expires_at: Date?
    let consumed_at: Date?
    let merchant_id: UUID
    let reward_id: UUID
    // Joined columns (PostgREST nested select)
    let rewards: NestedReward?
    let merchants: NestedMerchant?

    struct NestedReward: Codable, Hashable {
        let title: String
        let reward_type: String
        let value_pct: Double?
        let value_amount_cents: Int?
    }

    struct NestedMerchant: Codable, Hashable {
        let slug: String
        let name: String
    }

    enum Status: String {
        case active, expired, consumed
    }

    var status: Status {
        if consumed_at != nil { return .consumed }
        if let exp = expires_at, exp < Date() { return .expired }
        return .active
    }

    var rewardTitle: String { rewards?.title ?? "Reward" }
    var merchantName: String { merchants?.name ?? "Merchant" }
}
