import Foundation

/// Client for the deployed `local-guide` edge function on the Locals Supabase
/// project. The function resolves the caller's Friend account from their
/// `custom:friend` identity, grounds a turn in real Locals merchant data + the
/// person's travelling Friend memory, and returns the reply. Native port of the
/// web `src/lib/localGuide.ts` client.
///
/// The guide is gated (client-side) on the `friend` RevenueCat entitlement AND a
/// linked Friend; this service is only called once both hold, so a 401 here means
/// the session lapsed rather than "not entitled".
struct GuideReply {
    var friendConnected: Bool
    var friendName: String?
    var reply: String?
    var error: String?
}

enum LocalGuideService {
    /// Ask the local guide a question. `accessToken` is the Locals Supabase
    /// session token. Never throws - network / server failures return a
    /// user-presentable reply so the chat degrades gracefully.
    static func ask(_ message: String, accessToken: String?) async -> GuideReply {
        guard let token = accessToken, !token.isEmpty else {
            return GuideReply(friendConnected: false, error: "not_authenticated")
        }
        let url = LocalsConfig.supabaseURL.appendingPathComponent("functions/v1/local-guide")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(LocalsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["message": message])
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return GuideReply(friendConnected: true, reply: "I could not reach your guide just then. Give it another go in a moment.", error: "no_response")
            }
            if http.statusCode == 401 {
                return GuideReply(friendConnected: false, error: "not_authenticated")
            }
            if !(200...299).contains(http.statusCode) {
                return GuideReply(friendConnected: true, reply: "I could not reach your guide just then. Give it another go in a moment.", error: "http_\(http.statusCode)")
            }
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            return GuideReply(
                friendConnected: (obj["friend_connected"] as? Bool) ?? true,
                friendName: obj["friendName"] as? String,
                reply: obj["reply"] as? String,
                error: obj["error"] as? String
            )
        } catch {
            return GuideReply(friendConnected: true, reply: "I could not reach your guide just then. Check your connection and try again.", error: "network")
        }
    }
}
