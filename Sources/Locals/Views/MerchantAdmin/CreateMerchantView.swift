import SwiftUI

/// The merchant signup flow. Three short steps - name + category, then
/// location (uses CoreLocation when permitted, falls back to manual lat/lng
/// entry), then optional sustainability tags. One RPC call lands a
/// merchant + ownership row in a single transaction.
struct CreateMerchantView: View {
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var owners: OwnerMerchantService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var slug: String = ""
    @State private var category: MerchantCategory = .cafe
    @State private var address: String = ""
    @State private var story: String = ""
    @State private var tags: Set<SustainabilityTag> = []
    @State private var useDeviceLocation: Bool = true
    @State private var inFlight: Bool = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("About your business") {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, n in
                            if slug.isEmpty { slug = derive(n) }
                        }
                    Picker("Category", selection: $category) {
                        ForEach(MerchantCategory.allCases.filter { $0 != .other }) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    TextField("Web-friendly name (e.g. buderim-cafe)", text: $slug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Where you are") {
                    Toggle("Use my current location", isOn: $useDeviceLocation)
                    TextField("Street address (shown to customers)", text: $address)
                }

                Section("Story (optional)") {
                    TextField("Two or three sentences works best", text: $story, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("What you stand for (optional)") {
                    ForEach(SustainabilityTag.allCases) { tag in
                        Toggle(tag.label, isOn: Binding(
                            get: { tags.contains(tag) },
                            set: { on in if on { tags.insert(tag) } else { tags.remove(tag) } }
                        ))
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LocalsTheme.bg)
            .navigationTitle("Add your business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if inFlight { ProgressView() } else { Text("List it") }
                    }
                    .disabled(inFlight || name.isEmpty || slug.isEmpty)
                }
            }
        }
    }

    private func derive(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let lower = raw.lowercased().replacingOccurrences(of: " ", with: "-")
        return String(lower.unicodeScalars.filter { allowed.contains($0) })
    }

    @MainActor
    private func submit() async {
        inFlight = true
        defer { inFlight = false }
        let coord = location.coordinate
        do {
            _ = try await owners.create(
                name: name,
                slug: slug,
                category: category.rawValue,
                lat: coord.latitude,
                lng: coord.longitude,
                story: story.isEmpty ? nil : story,
                address: address.isEmpty ? nil : address,
                tags: Array(tags)
            )
            Haptics.success()
            dismiss()
        } catch {
            Haptics.warn()
            self.error = error.localizedDescription
        }
    }
}
