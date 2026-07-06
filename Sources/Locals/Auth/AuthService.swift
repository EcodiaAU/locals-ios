import Foundation
import Supabase
import AuthenticationServices
import CryptoKit
import UIKit

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

    // MARK: - Connect your Friend (native OIDC federation, primary path)

    /// Connect your Friend: the native leg of the Ecodia Friend federation.
    ///
    /// Friend is a `custom:friend` OIDC provider on the Locals Supabase project
    /// (it federates to the Friend IdP, issuer `eionabtkzyjnipwfdsfy`). The Locals
    /// project still mints its OWN local session on success, so every existing
    /// `auth.uid()`-keyed RLS policy keeps working unchanged; the local user's
    /// `app_metadata.friend_id` is populated by the project's friend_id trigger
    /// pair (`friend_copy_friend_id_on_identity` + `friend_inject_friend_id_on_user`),
    /// which is what resolves this Locals user to the one canonical Friend person
    /// across apps.
    ///
    /// supabase-swift's `Provider` enum has no `custom:` case, so
    /// `signInWithOAuth` cannot carry `custom:friend`, and its internal
    /// code-verifier storage returns nil on the custom-provider path (the token
    /// exchange then fails with "both auth code and code verifier should be
    /// non-empty"). We therefore run the OAuth 2.1 + PKCE flow ourselves:
    /// generate the verifier/challenge, hit the project's `authorize` endpoint
    /// with `provider=custom:friend`, present it in an
    /// `ASWebAuthenticationSession`, then exchange the returned code at
    /// `token?grant_type=pkce` with the verifier we hold locally, and hand the
    /// tokens to the SDK via `setSession`. Doctrine:
    /// supabase-swift-custom-provider-needs-self-managed-pkce-2026-07-06.
    func signInWithFriend() async throws {
        let verifier = AuthService.makeCodeVerifier()
        let challenge = AuthService.codeChallenge(for: verifier)

        guard var authorizeComps = URLComponents(
            url: LocalsConfig.supabaseURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        ) else { throw AuthError.friendAuth("Could not build the sign-in URL.") }
        authorizeComps.queryItems = [
            URLQueryItem(name: "provider", value: "custom:friend"),
            URLQueryItem(name: "redirect_to", value: "locals://auth/callback"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        guard let authorizeURL = authorizeComps.url else {
            throw AuthError.friendAuth("Could not build the sign-in URL.")
        }

        let callback = try await AuthService.presentWebAuth(
            url: authorizeURL, callbackScheme: "locals"
        )

        // GoTrue surfaces failures on the redirect as ?error / ?error_description.
        if let message = AuthService.callbackError(from: callback) {
            throw AuthError.friendAuth(message)
        }
        guard let code = AuthService.authCode(from: callback) else {
            throw AuthError.friendAuth("Sign-in did not return an authorization code.")
        }

        let tokens = try await exchangeFriendCode(code, verifier: verifier)
        let session = try await client.auth.setSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )
        currentUser = session.user
        await notifySignedIn()
    }

    /// Exchange a PKCE authorization code for a session at the project's token
    /// endpoint, supplying the verifier we generated (never the SDK's storage).
    private func exchangeFriendCode(_ code: String, verifier: String) async throws -> FriendTokens {
        guard var comps = URLComponents(
            url: LocalsConfig.supabaseURL.appendingPathComponent("auth/v1/token"),
            resolvingAgainstBaseURL: false
        ) else { throw AuthError.friendAuth("Could not build the token URL.") }
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "pkce")]
        guard let tokenURL = comps.url else {
            throw AuthError.friendAuth("Could not build the token URL.")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue(LocalsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["auth_code": code, "code_verifier": verifier]
        )
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.friendAuth("Unexpected response from the server.")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(GoTrueError.self, from: data))?.readable
                ?? "Sign-in could not complete (error \(http.statusCode))."
            throw AuthError.friendAuth(message)
        }
        return try JSONDecoder().decode(FriendTokens.self, from: data)
    }

    // MARK: PKCE helpers (self-managed so the exchange never depends on SDK storage)

    static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<64).map { _ in UInt8.random(in: 0...255) }
        }
        return Data(bytes).friendBase64URLEncoded()
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).friendBase64URLEncoded()
    }

    /// Read the `code` from a PKCE redirect (query first, fragment as a fallback).
    static func authCode(from url: URL) -> String? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let code = comps.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            return code
        }
        if let fragment = comps.fragment {
            for pair in fragment.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2, kv[0] == "code", !kv[1].isEmpty {
                    return String(kv[1]).removingPercentEncoding ?? String(kv[1])
                }
            }
        }
        return nil
    }

    /// Surface a GoTrue error carried back on the redirect (`?error_description`).
    static func callbackError(from url: URL) -> String? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = comps.queryItems ?? []
        if let desc = items.first(where: { $0.name == "error_description" })?.value {
            return desc.replacingOccurrences(of: "+", with: " ")
        }
        return items.first(where: { $0.name == "error" })?.value
    }

    /// Present the OAuth authorize URL in an `ASWebAuthenticationSession` and
    /// resolve with the custom-scheme callback URL. Mirrors what supabase-swift's
    /// built-in ASWebAuthenticationSession overload does, exposed here so the
    /// Friend flow can hand it a URL whose provider we rewrote.
    @MainActor
    static func presentWebAuth(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let contextProvider = WebAuthPresentationContext()
            let webSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthError.webAuthNoCallback)
                }
                _ = contextProvider
            }
            webSession.presentationContextProvider = contextProvider
            webSession.start()
        }
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
    case webAuthNoCallback
    /// Friend federation failure, carrying a user-presentable message.
    case friendAuth(String)

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken: return "Apple did not return an identity token. Try again."
        case .notSignedIn:          return "You need to be signed in for that."
        case .deleteFailed:         return "Could not delete your account. Try again, or email code@ecodia.au."
        case .magicLinkFailed:      return "Could not send the magic link. Check your email and try again."
        case .webAuthNoCallback:    return "Sign-in did not complete."
        case .friendAuth(let message): return message
        }
    }
}

/// Access + refresh tokens from GoTrue's `token?grant_type=pkce` exchange.
private struct FriendTokens: Decodable {
    let accessToken: String
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

/// GoTrue error envelope, decoded to surface a readable message on a failed exchange.
private struct GoTrueError: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let message: String?
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case msg
        case message
    }
    var readable: String {
        errorDescription ?? message ?? msg ?? error ?? "Sign-in could not complete."
    }
}

private extension Data {
    /// Base64URL (RFC 4648 s5) without padding, as PKCE requires.
    func friendBase64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Anchors the `ASWebAuthenticationSession` sheet to the app's foreground window.
private final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
    }
}
