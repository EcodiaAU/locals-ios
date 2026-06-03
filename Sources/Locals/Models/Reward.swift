import Foundation

struct Reward: Codable, Identifiable, Hashable {
    let id: UUID
    let merchant_id: UUID
    let title: String
    let description: String?
    let reward_type: String
    let value_pct: Double?
    let value_amount_cents: Int?
    let max_redemptions_per_user: Int?
    let max_total_redemptions: Int?
    let starts_at: Date?
    let ends_at: Date?
    let is_active: Bool?
    let is_first_visit: Bool?
    let valid_from: Date?
    let valid_until: Date?
    let created_at: Date?

    var resolvedType: RewardType { RewardType(rawValue: reward_type) ?? .freebie }

    /// Human-readable "format" string for the detail page: e.g. "20% off",
    /// "$5 off", "Free pastry", "Buy 2 get 1". The locals-web build derives
    /// this client-side; mirroring the logic so the iOS detail page reads
    /// the same.
    var format: String {
        switch resolvedType {
        case .percent_off:
            if let v = value_pct { return "\(Int(v.rounded()))% off" }
            return "Discount"
        case .amount_off:
            if let cents = value_amount_cents {
                let dollars = Double(cents) / 100
                return "$\(Int(dollars.rounded())) off"
            }
            return "Discount"
        case .bundle:  return "Bundle"
        case .freebie: return "On the house"
        }
    }
}
