import SwiftUI
import AuthenticationServices

/// Sign in. Apple primary; magic link as the fallback for people who don't
/// want to use Apple ID. Surfaces inline error states.
struct SignInView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var nonce: (raw: String, hashed: String)?
    @State private var email: String = ""
    @State private var magicLinkSent: Bool = false
    @State private var error: String?
    @State private var inFlight: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xxl) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                        Eyebrow(text: "Sign in")
                        Text("Save businesses,\nuse rewards.")
                            .font(LocalsTheme.display(DesignTokens.Size.h2, italic: true))
                            .foregroundStyle(LocalsTheme.fg)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Sign in to save favourites, redeem rewards at the counter, and list your business.")
                            .font(LocalsTheme.body(DesignTokens.Size.base))
                            .foregroundStyle(LocalsTheme.fgMuted)
                    }

                    appleButton

                    divider

                    magicLinkBlock

                    if let error {
                        Text(error)
                            .font(LocalsTheme.body(DesignTokens.Size.sm))
                            .foregroundStyle(.red)
                            .padding(.top, DesignTokens.Space.sm)
                    }
                }
                .padding(.horizontal, DesignTokens.Space.lg)
                .padding(.top, DesignTokens.Space.lg)
            }
            .background(LocalsTheme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let n = AuthService.makeNonce()
            nonce = n
            request.requestedScopes = [.email, .fullName]
            request.nonce = n.hashed
        } onCompletion: { result in
            handleApple(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 52)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
    }

    private var divider: some View {
        HStack(spacing: DesignTokens.Space.md) {
            Rectangle().fill(LocalsTheme.borderSubtle).frame(height: 1)
            Text("or")
                .font(LocalsTheme.body(DesignTokens.Size.sm))
                .foregroundStyle(LocalsTheme.fgMuted)
            Rectangle().fill(LocalsTheme.borderSubtle).frame(height: 1)
        }
    }

    @ViewBuilder
    private var magicLinkBlock: some View {
        if magicLinkSent {
            VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                Text("Check your email")
                    .font(LocalsTheme.body(DesignTokens.Size.lg, weight: .semibold))
                Text("We sent a sign-in link to \(email). Tap it to come back.")
                    .font(LocalsTheme.body(DesignTokens.Size.base))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            .padding(DesignTokens.Space.lg)
            .background(LocalsTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                Text("Or send a magic link")
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .medium))
                    .foregroundStyle(LocalsTheme.fg)
                TextField("you@somewhere.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, DesignTokens.Space.lg)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                            .strokeBorder(LocalsTheme.border)
                    )
                Button {
                    Task { await sendMagic() }
                } label: {
                    if inFlight {
                        ProgressView().tint(LocalsTheme.onAccent)
                    } else {
                        Text("Send link")
                    }
                }
                .buttonStyle(.localsPrimary)
                .disabled(inFlight || email.isEmpty)
            }
        }
    }

    private func sendMagic() async {
        inFlight = true
        defer { inFlight = false }
        do {
            try await auth.sendMagicLink(email: email)
            magicLinkSent = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let err):
            error = err.localizedDescription
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce else {
                error = "Sign in cancelled."
                return
            }
            Task {
                inFlight = true
                defer { inFlight = false }
                do {
                    try await self.auth.signInWithApple(credential: credential, rawNonce: nonce.raw)
                    dismiss()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
