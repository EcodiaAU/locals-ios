import Foundation

@MainActor
final class FeedbackService: ObservableObject {
    /// Post to the feedback-send edge function. Works signed-out (the
    /// function has no auth requirement); we just include the path the
    /// user sent from for context.
    func send(kind: String, body: String, contact: String?, path: String?) async throws {
        struct Payload: Encodable {
            let kind: String
            let body: String
            let contact: String?
            let path: String?
        }

        var request = URLRequest(
            url: LocalsConfig.supabaseURL.appendingPathComponent("functions/v1/feedback-send")
        )
        request.httpMethod = "POST"
        request.setValue(LocalsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(LocalsConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Payload(
            kind: kind,
            body: body,
            contact: contact,
            path: path
        ))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FeedbackError.sendFailed
        }
    }
}

enum FeedbackError: LocalizedError {
    case sendFailed
    var errorDescription: String? {
        switch self {
        case .sendFailed: return "Could not send your message. Try again, or email code@ecodia.au."
        }
    }
}
