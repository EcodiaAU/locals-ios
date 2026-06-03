import Foundation
import Supabase

@MainActor
final class RedemptionService: ObservableObject {
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    /// Customer asks for a 5-minute code. Idempotent: hitting it twice in
    /// quick succession returns the SAME live code rather than burning the
    /// per-customer cap.
    func issue(rewardId: UUID) async throws -> IssuedRedemption {
        struct Params: Encodable { let p_reward_id: UUID }
        let rows: [IssuedRedemption] = try await client
            .rpc("issue_redemption", params: Params(p_reward_id: rewardId))
            .execute()
            .value
        guard let first = rows.first else {
            throw RedemptionError.unknown
        }
        return first
    }

    /// Merchant scans a code at the counter.
    func consume(code: String, merchantId: UUID) async throws -> ConsumedRedemption {
        struct Params: Encodable {
            let p_code: String
            let p_merchant_id: UUID
        }
        let rows: [ConsumedRedemption] = try await client
            .rpc("consume_redemption", params: Params(
                p_code: code.uppercased(),
                p_merchant_id: merchantId
            ))
            .execute()
            .value
        guard let first = rows.first else {
            throw RedemptionError.codeInvalid
        }
        return first
    }

    /// "My redemptions" - last N codes for the signed-in user, joined with
    /// reward + merchant for label display. RLS filters to the caller.
    func mine(limit: Int = 50) async throws -> [RedemptionRow] {
        let rows: [RedemptionRow] = try await client
            .from("redemptions")
            .select("""
                id, code, redeemed_at, expires_at, consumed_at, merchant_id,
                reward_id,
                rewards(title, reward_type, value_pct, value_amount_cents),
                merchants(slug, name)
            """)
            .order("redeemed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }
}

enum RedemptionError: LocalizedError {
    case codeInvalid
    case unknown

    var errorDescription: String? {
        switch self {
        case .codeInvalid: return "That code is invalid, expired, or already used."
        case .unknown:     return "Could not issue a code. Try again."
        }
    }
}

// Surface the PostgREST error name to a humanised string. The RPC raises
// codes like 'not_authenticated', 'inactive_reward', 'per_customer_limit'
// etc; this maps the common ones for the issue-code UI.
extension Error {
    var localsHumanMessage: String {
        let s = (self as NSError).localizedDescription
        if s.contains("not_authenticated") { return "Sign in to get a code." }
        if s.contains("inactive_reward")   { return "That reward is no longer active." }
        if s.contains("per_customer_limit"){ return "You've already used this reward the max number of times." }
        if s.contains("first_visit_only")  { return "This reward is for first-time visits only." }
        if s.contains("not_authorised_for_merchant") { return "You can't redeem codes for this business." }
        if s.contains("code_not_found_or_used_or_expired") { return "That code is invalid, expired, or already used." }
        return s
    }
}
