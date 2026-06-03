import Foundation

// Returned by the sustainability_signal RPC - per-tag confirmed percentage
// once a merchant has gathered enough signal (>=10 visits with feedback).
struct SustainabilitySignal: Codable, Identifiable, Hashable {
    let tag: String
    let pct: Double
    let n: Int

    var id: String { tag }
    var resolvedTag: SustainabilityTag? { SustainabilityTag(rawValue: tag) }
    var percentLabel: String { "\(Int(pct.rounded()))%" }
}
