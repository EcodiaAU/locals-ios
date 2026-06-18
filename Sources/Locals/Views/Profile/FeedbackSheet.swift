import SwiftUI

struct FeedbackSheet: View {
    @EnvironmentObject var feedback: FeedbackService
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var contact: String = ""
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                    if sent {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                            Text("Thanks for the note.")
                                .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
                            Text("We read everything. We'll email back if you left an address.")
                                .font(LocalsTheme.body(DesignTokens.Size.sm))
                                .foregroundStyle(LocalsTheme.fgMuted)
                        }
                    } else {
                        Eyebrow(text: "What's on your mind")
                        TextEditor(text: $message)
                            .scrollContentBackground(.hidden)
                            .padding(DesignTokens.Space.md)
                            .frame(minHeight: 180)
                            .background(LocalsTheme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))

                        Eyebrow(text: "How to reach you (optional)")
                        TextField(auth.currentUser?.email ?? "you@somewhere.com", text: $contact)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(.horizontal, DesignTokens.Space.md)
                            .frame(height: 52)
                            .background(LocalsTheme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))

                        if let error {
                            Text(error)
                                .font(LocalsTheme.body(DesignTokens.Size.sm))
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await send() }
                        } label: {
                            if sending { ProgressView().tint(LocalsTheme.onAccent) }
                            else { Text("Send") }
                        }
                        .buttonStyle(.localsPrimary)
                        .disabled(sending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(DesignTokens.Space.lg)
            }
            .background(LocalsTheme.bg)
            .navigationTitle("Tell us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func send() async {
        sending = true
        defer { sending = false }
        do {
            try await feedback.send(
                kind: "ios",
                body: message,
                contact: contact.isEmpty ? auth.currentUser?.email : contact,
                path: "ios.profile.feedback"
            )
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
