import Foundation

// Mirror the Postgres enums in locals-shared/supabase/migrations.

enum MerchantStatus: String, Codable, CaseIterable {
    case draft
    case pending_review
    case active
    case paused
    case archived
}

enum MerchantRole: String, Codable {
    case owner
    case staff
    // The DB column is two-valued, but the schema doc lists "manager" too.
    // Forward-compat: tolerate unknowns by mapping to staff.
}

enum RewardType: String, Codable, CaseIterable, Identifiable {
    case percent_off
    case amount_off
    case bundle
    case freebie

    var id: String { rawValue }

    var label: String {
        switch self {
        case .percent_off: return "Percent off"
        case .amount_off:  return "Amount off"
        case .bundle:      return "Bundle"
        case .freebie:     return "Freebie"
        }
    }
}

enum SustainabilityTag: String, Codable, CaseIterable, Identifiable {
    case local_sourced
    case plastic_free
    case fair_pay
    case renewable_powered
    case low_waste
    case organic
    case second_hand
    case community_owned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .local_sourced:     return "Local sourced"
        case .plastic_free:      return "Plastic free"
        case .fair_pay:          return "Fair pay"
        case .renewable_powered: return "Renewable powered"
        case .low_waste:         return "Low waste"
        case .organic:           return "Organic"
        case .second_hand:       return "Second hand"
        case .community_owned:   return "Community owned"
        }
    }
}

enum MerchantCategory: String, CaseIterable, Identifiable {
    case cafe
    case food
    case retail
    case services
    case accommodation
    case tours
    case other

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    static func resolve(_ raw: String?) -> MerchantCategory {
        guard let raw = raw?.lowercased() else { return .other }
        return MerchantCategory(rawValue: raw) ?? .other
    }
}
