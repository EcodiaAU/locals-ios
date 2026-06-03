import SwiftUI

struct MerchantEditView: View {
    let merchantId: UUID

    @EnvironmentObject var merchants: MerchantService
    @EnvironmentObject var owners: OwnerMerchantService

    @State private var merchant: Merchant?
    @State private var name: String = ""
    @State private var story: String = ""
    @State private var address: String = ""
    @State private var category: String = ""
    @State private var tags: Set<SustainabilityTag> = []
    @State private var ownerNote: String = ""
    @State private var status: MerchantStatus = .active
    @State private var saving = false
    @State private var error: String?
    @State private var savedFlash: Bool = false

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(MerchantCategory.allCases.filter { $0 != .other }) { c in
                        Text(c.label).tag(c.rawValue)
                    }
                }
                TextField("Address", text: $address)
            }
            Section("Story") {
                TextField("What you do, who you do it for", text: $story, axis: .vertical)
                    .lineLimit(4...12)
            }
            Section {
                NavigationLink("Theme + font") {
                    MerchantThemeView(merchantId: merchantId,
                                     initialColor: merchant?.theme_color,
                                     initialFont: merchant?.theme_font)
                }
            }
            Section("Owner note") {
                TextField("Closed today, mum's birthday", text: $ownerNote, axis: .vertical)
                    .lineLimit(2...6)
                Text("Customers see this at the top of your page. Keep it short.")
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            Section("What you stand for") {
                ForEach(SustainabilityTag.allCases) { tag in
                    Toggle(tag.label, isOn: Binding(
                        get: { tags.contains(tag) },
                        set: { on in if on { tags.insert(tag) } else { tags.remove(tag) } }
                    ))
                }
            }
            Section("Visibility") {
                Picker("Status", selection: $status) {
                    Text("Active").tag(MerchantStatus.active)
                    Text("Paused").tag(MerchantStatus.paused)
                    Text("Draft").tag(MerchantStatus.draft)
                    Text("Archive").tag(MerchantStatus.archived)
                }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(LocalsTheme.bg)
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text(savedFlash ? "Saved" : "Save") }
                }
                .disabled(saving)
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            let m = try await merchants.detailById(merchantId)
            merchant = m
            name = m.name
            story = m.story ?? ""
            address = m.address ?? ""
            category = m.category
            tags = Set(m.tags)
            ownerNote = m.owner_note ?? ""
            status = m.resolvedStatus
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await owners.updateBasics(
                merchantId: merchantId,
                name: name,
                story: story.isEmpty ? nil : story,
                address: address.isEmpty ? nil : address,
                category: category,
                tags: Array(tags)
            )
            if let m = merchant, (m.owner_note ?? "") != ownerNote {
                try await owners.setOwnerNote(merchantId: merchantId, note: ownerNote)
            }
            if let m = merchant, m.resolvedStatus != status {
                try await owners.setStatus(merchantId: merchantId, status: status)
            }
            Haptics.success()
            savedFlash = true
            await owners.refresh()
            try? await Task.sleep(for: .seconds(1.2))
            savedFlash = false
        } catch {
            Haptics.warn()
            self.error = error.localizedDescription
        }
    }
}
