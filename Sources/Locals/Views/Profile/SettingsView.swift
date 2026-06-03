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
                    Link("Terms", destination: URL(string: "https://locals.ecodia.au/terms")!)
                    Link("Privacy", destination: URL(string: "https://locals.ecodia.au/privacy")!)
                    Link("Email us", destination: URL(string: "mailto:code@ecodia.au")!)
                }

                if auth.currentUser != nil {
                    Section {
                        Button("Delete account", role: .destructive) {
                            showDelete = true
                        }
                    }
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
                Text("This permanently removes your account, your saved businesses, and your codes. You can't undo this.")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
