import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isReady = false
    @Published private(set) var inFlight = false

    let client: SupabaseClient

    /// Sign-in sync hook. Fired with the fresh access token right after any
    /// successful sign-in path sets `currentUser`. Wired by the app to refresh
    /// favorites, owned merchants, etc., without AuthService having to know
    /// about them.
    var onSignIn: ((_ accessToken: String?) -> Void)?
    var onSignOut: (() -> Void)?

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    func bootstrap() async {
        defer { isReady = true }
        do {
            let session = try await client.auth.session
            currentUser = session.user
        } catch {
            currentUser = nil
        }
    }

    func accessToken() async -> String? {
        try? await client.auth.session.accessToken
    }

    func signOut() async {
        try? await client.auth.signOut()
        currentUser = nil
        onSignOut?()
    }

    // MARK: - Sign in with Apple (primary path on iOS)

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.missingIdentityToken
        }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )
        currentUser = session.user
        await notifySignedIn()
    }

    /// Generate a fresh raw nonce + its sha256, both returned so the caller
    /// can hand the sha256 to ASAuthorizationAppleIDProvider and feed the raw
    /// nonce back into signInWithApple after the credential lands.
    static func makeNonce() -> (raw: String, sha256: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let raw = bytes.map { String(format: "%02x", $0) }.joined()
        let hashed = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return (raw, hashed)
    }

    // MARK: - Magic link fallback

    func sendMagicLink(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try await client.auth.signInWithOTP(
            email: trimmed,
            redirectTo: URL(string: "locals://auth/callback")
        )
    }

    // MARK: - Account deletion (Apple Guideline 5.1.1(v))

    func deleteAccount() async throws {
        guard let token = await accessToken() else {
            throw AuthError.notSignedIn
        }
        var request = URLRequest(
            url: LocalsConfig.supabaseURL.appendingPathComponent("functions/v1/account-delete")
        )
        request.httpMethod = "POST"
        request.setValue(LocalsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.deleteFailed
        }

        try? await client.auth.signOut()
        currentUser = nil
        onSignOut?()
    }

    private func notifySignedIn() async {
        let token = await accessToken()
        onSignIn?(token)
    }
}

enum AuthError: LocalizedError {
    case missingIdentityToken
    case notSignedIn
    case deleteFailed
    case magicLinkFailed

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken: return "Apple did not return an identity token. Try again."
        case .notSignedIn:          return "You need to be signed in for that."
        case .deleteFailed:         return "Could not delete your account. Try again, or email code@ecodia.au."
        case .magicLinkFailed:      return "Could not send the magic link. Check your email and try again."
        }
    }
}
