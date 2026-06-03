import Foundation
import Supabase

@MainActor
final class BillingService: ObservableObject {
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    /// Open a Stripe Checkout session for the merchant's pay-what-you-want
    /// monthly subscription. Returns the redirect URL the caller hands to
    /// SFSafariViewController. Apple's 2024 reader pattern allows external
    /// purchase flows for merchant-side B2B services; this is not IAP.
    func checkout(merchantId: UUID, amountCents: Int) async throws -> URL {
        struct Body: Encodable {
            let merchant_id: UUID
            let amount_cents: Int
            let success_url: String?
            let cancel_url: String?
        }
        struct Reply: Decodable { let url: String }

        guard let token = try? await client.auth.session.accessToken else {
            throw BillingError.notSignedIn
        }
        var request = URLRequest(
            url: LocalsConfig.supabaseURL.appendingPathComponent("functions/v1/billing-checkout")
        )
        request.httpMethod = "POST"
        request.setValue(LocalsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(
            merchant_id: merchantId,
            amount_cents: max(100, amountCents),
            success_url: "https://locals.ecodia.au/billing/success",
            cancel_url: "https://locals.ecodia.au/billing/cancel"
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BillingError.checkoutFailed
        }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard let url = URL(string: reply.url) else { throw BillingError.checkoutFailed }
        return url
    }

    func cancel(merchantId: UUID) async throws {
        struct Body: Encodable { let merchant_id: UUID }
        guard let token = try? await client.auth.session.accessToken else {
            throw BillingError.notSignedIn
        }
        var request = URLRequest(
            url: LocalsConfig.supabaseURL.appendingPathComponent("functions/v1/billing-cancel")
        )
        request.httpMethod = "POST"
        request.setValue(LocalsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(merchant_id: merchantId))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BillingError.cancelFailed
        }
    }
}

enum BillingError: LocalizedError {
    case notSignedIn
    case checkoutFailed
    case cancelFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:    return "Sign in to manage billing."
        case .checkoutFailed: return "Could not open checkout. Try again."
        case .cancelFailed:   return "Could not cancel. Try again, or email code@ecodia.au."
        }
    }
}
