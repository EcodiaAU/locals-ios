import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Crowd signal") {
                    Toggle("Share my anonymous presence", isOn: $session.pulseEnabled)
                    Text("When this is on, dwelling near a business for a few minutes adds to the anonymous 'N here in the last hour' signal on its page. We never store who you are or where you've been - only that someone was nearby.")
                        .font(LocalsTheme.body(DesignTokens.Size.xs))
                        .foregroundStyle(LocalsTheme.fgMuted)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link("locals.ecodia.au", destination: URL(string: "https://locals.ecodia.au")!)
                    Link("Terms", destination: URL(string: "https://locals.ecodia.au/legal#terms")!)
                    Link("Privacy", destination: URL(string: "https://locals.ecodia.au/legal#privacy")!)
                    Link("Email us", destination: URL(string: "mailto:code@ecodia.au")!)
                }

                if auth.currentUser != nil {
                    Section {
                        Button("Delete account", role: .destructive) {
                            showDelete = true
                        }
                    }
                }

                // The Ecodia attribution mark. Receding, italic serif, no
                // underline (plain button style strips the default Link tint
                // and underline). EB Garamond is not bundled on iOS, so the
                // bundled italic serif (Spectral-Italic) renders the same
                // receding register.
                Section {
                    EcodiaAttribution()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LocalsTheme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Delete account?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) {
                    Task { try? await auth.deleteAccount(); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your account and your personal data: your favourites, your redemptions, your check-ins, and your sustainability confirmations. Any business listing you manage stays on Locals (a listing is public information others rely on); your access to it is removed. You can't undo this.")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
