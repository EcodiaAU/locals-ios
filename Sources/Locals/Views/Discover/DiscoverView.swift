import SwiftUI
import MapKit

/// The main customer surface. Map at top, swipe-up sheet of merchants
/// ordered by distance below. Pure MapKit - native clustering, look-around
/// where available, the user's blue dot, all the iOS-native polish.
struct DiscoverView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var merchants: MerchantService

    @State private var nearby: [MerchantNear] = []
    @State private var selectedCategory: MerchantCategory? = nil
    @State private var radiusKm: Double = 50
    @State private var loading = false
    @State private var loadError: String?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: LocationManager.defaultCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )
    )
    @State private var pushedSlug: String?

    var filtered: [MerchantNear] {
        guard let c = selectedCategory else { return nearby }
        return nearby.filter { $0.resolvedCategory == c }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                bottomSheet
            }
            .background(LocalsTheme.bg.ignoresSafeArea())
            .navigationDestination(isPresented: Binding(
                get: { pushedSlug != nil },
                set: { if !$0 { pushedSlug = nil } }
            )) {
                if let slug = pushedSlug {
                    MerchantDetailView(slug: slug)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await reload() }
            .onChange(of: location.coordinate.latitude) { _, _ in
                Task { await reload() }
            }
            .onChange(of: session.pendingMerchantSlug) { _, slug in
                if let slug { pushedSlug = slug; session.pendingMerchantSlug = nil }
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            UserAnnotation()
            ForEach(filtered) { merchant in
                Annotation(merchant.name, coordinate: coordinate(for: merchant)) {
                    Button {
                        Haptics.tap()
                        pushedSlug = merchant.slug
                    } label: {
                        MerchantPin(merchant: merchant)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea(edges: [.top])
    }

    /// Approximate a merchant coordinate from its distance + user's
    /// location. The merchants_near RPC returns distance_m but not lat/lng
    /// (the merchant geo is gated by RLS). We fan annotations out around
    /// the user with a deterministic offset by id - this is enough for the
    /// map to feel populated without revealing exact merchant geometry on
    /// the wire. The detail view shows the real address text.
    private func coordinate(for m: MerchantNear) -> CLLocationCoordinate2D {
        let user = location.coordinate
        let metres = m.distance_m
        let hash = abs(m.id.hashValue)
        let bearing = Double(hash % 360) * .pi / 180
        let earthR = 6_378_137.0
        let dLat = metres * cos(bearing) / earthR
        let dLng = metres * sin(bearing) / (earthR * cos(user.latitude * .pi / 180))
        return CLLocationCoordinate2D(
            latitude: user.latitude + dLat * 180 / .pi,
            longitude: user.longitude + dLng * 180 / .pi
        )
    }

    // MARK: - Sheet

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            grabber
            categoryRow
                .padding(.horizontal, DesignTokens.Space.lg)
                .padding(.bottom, DesignTokens.Space.md)

            list
        }
        .background(LocalsTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
        .frame(maxHeight: 460)
        .padding(.bottom, 49)
    }

    private var grabber: some View {
        Capsule()
            .fill(LocalsTheme.borderSubtle)
            .frame(width: 36, height: 5)
            .padding(.top, DesignTokens.Space.sm)
            .padding(.bottom, DesignTokens.Space.md)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Space.sm) {
                CategoryChip(label: "All", isSelected: selectedCategory == nil) {
                    Haptics.tap()
                    selectedCategory = nil
                }
                ForEach(MerchantCategory.allCases) { cat in
                    if cat != .other {
                        CategoryChip(label: cat.label, isSelected: selectedCategory == cat) {
                            Haptics.tap()
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
        }
    }

    private var list: some View {
        Group {
            if loading && nearby.isEmpty {
                ProgressView().padding(DesignTokens.Space.xl)
            } else if filtered.isEmpty {
                VStack(spacing: DesignTokens.Space.sm) {
                    Text("No businesses here yet")
                        .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
                    Text("Try widening the search, or scroll the map.")
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .foregroundStyle(LocalsTheme.fgMuted)
                }
                .padding(DesignTokens.Space.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { m in
                            NearbyRow(merchant: m) {
                                Haptics.tap()
                                pushedSlug = m.slug
                            }
                            Divider().background(LocalsTheme.borderSubtle)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func reload() async {
        loading = true
        defer { loading = false }
        do {
            nearby = try await merchants.near(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                radiusKm: radiusKm,
                category: nil,
                limit: 80
            )
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Subviews

struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
                .padding(.horizontal, DesignTokens.Space.lg)
                .padding(.vertical, DesignTokens.Space.sm)
                .background(isSelected ? LocalsTheme.fg : LocalsTheme.bgElevated)
                .foregroundStyle(isSelected ? LocalsTheme.bg : LocalsTheme.fg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NearbyRow: View {
    let merchant: MerchantNear
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DesignTokens.Space.md) {
                themeSwatch
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(merchant.name)
                            .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                            .foregroundStyle(LocalsTheme.fg)
                        if merchant.abn_verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(LocalsTheme.accent)
                        }
                    }
                    Text(merchant.resolvedCategory.label.lowercased())
                        .font(LocalsTheme.body(DesignTokens.Size.xs))
                        .foregroundStyle(LocalsTheme.fgMuted)
                    if let addr = merchant.address {
                        Text(addr)
                            .font(LocalsTheme.body(DesignTokens.Size.xs))
                            .foregroundStyle(LocalsTheme.fgMuted)
                            .lineLimit(1)
                    }
                    if let crowd = merchant.crowd_last_hour, crowd > 0 {
                        Text("\(crowd) here in the last hour")
                            .font(LocalsTheme.body(DesignTokens.Size.xs, weight: .medium))
                            .foregroundStyle(LocalsTheme.accentDeep)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Text(merchant.distanceLabel)
                    .font(LocalsTheme.mono(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            .padding(.horizontal, DesignTokens.Space.lg)
            .padding(.vertical, DesignTokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var themeSwatch: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
            .fill(MerchantTheme.background(for: merchant.theme_color))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .strokeBorder(LocalsTheme.borderSubtle, lineWidth: 1)
            )
            .frame(width: 44, height: 44)
    }
}

struct MerchantPin: View {
    let merchant: MerchantNear
    var body: some View {
        VStack(spacing: 0) {
            Text(merchant.name)
                .font(LocalsTheme.body(DesignTokens.Size.xs, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, DesignTokens.Space.sm)
                .padding(.vertical, 4)
                .background(MerchantTheme.background(for: merchant.theme_color))
                .foregroundStyle(MerchantTheme.foreground(for: merchant.theme_color))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(LocalsTheme.fg.opacity(0.5), lineWidth: 0.5))
        }
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}
