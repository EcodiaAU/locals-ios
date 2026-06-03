import SwiftUI
import MapKit
import CoreLocation

/// Discover - the customer surface. Edge-to-edge MapKit with native
/// controls anchored inside the safe area, a proper iOS sheet (with
/// real detents and a grabber that drags) for the merchant list, and
/// distance-based clustering so a busy region reads as a few clean
/// counts instead of a wall of overlapping pills.
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
    @State private var visibleSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
    @State private var visibleCenter: CLLocationCoordinate2D = LocationManager.defaultCoordinate
    @State private var pushedSlug: String?
    @State private var sheetDetent: PresentationDetent = .fraction(0.35)
    @State private var focusedMerchantId: UUID?

    var filtered: [MerchantNear] {
        guard let c = selectedCategory else { return nearby }
        return nearby.filter { $0.resolvedCategory == c }
    }

    var body: some View {
        NavigationStack {
            map
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) { topControls }
                .navigationDestination(isPresented: Binding(
                    get: { pushedSlug != nil },
                    set: { if !$0 { pushedSlug = nil } }
                )) {
                    if let slug = pushedSlug {
                        MerchantDetailView(slug: slug)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: .constant(true)) {
                    bottomSheet
                        .presentationDetents(
                            [.height(96), .fraction(0.35), .large],
                            selection: $sheetDetent
                        )
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.35)))
                        .presentationCornerRadius(DesignTokens.Radius.xxl)
                        .interactiveDismissDisabled(true)
                }
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

            // Clustered representation: one Annotation per cluster. A cluster
            // of size 1 renders as a labelled pin, anything bigger as a
            // count circle. The clustering radius scales with the visible
            // span so zooming in unfolds groups naturally.
            ForEach(clusters, id: \.id) { cluster in
                Annotation("", coordinate: cluster.coordinate) {
                    if cluster.merchants.count == 1, let m = cluster.merchants.first {
                        MerchantPin(merchant: m, focused: focusedMerchantId == m.id)
                            .onTapGesture { tapPin(m) }
                    } else {
                        ClusterPin(count: cluster.merchants.count)
                            .onTapGesture { zoomTo(cluster) }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { ctx in
            visibleSpan = ctx.region.span
            visibleCenter = ctx.region.center
        }
    }

    // MARK: - Top controls (native, inside safe area)

    private var topControls: some View {
        HStack(spacing: DesignTokens.Space.sm) {
            Spacer()
            Button {
                Haptics.tap()
                location.requestPermissionIfNeeded()
                withAnimation(.easeInOut(duration: 0.35)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LocalsTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, DesignTokens.Space.md)
        .padding(.top, DesignTokens.Space.sm)
    }

    // MARK: - Bottom sheet

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DesignTokens.Space.lg)
                .padding(.top, DesignTokens.Space.sm)
                .padding(.bottom, DesignTokens.Space.md)
            Divider().background(LocalsTheme.borderSubtle)
            list
        }
        .background(LocalsTheme.bg)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(filtered.isEmpty ? "Nothing here" : "\(filtered.count) nearby")
                    .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                    .foregroundStyle(LocalsTheme.fg)
                Text(categorySubtitle)
                    .font(LocalsTheme.body(DesignTokens.Size.xs))
                    .foregroundStyle(LocalsTheme.fgMuted)
            }
            Spacer()
            categoryMenu
        }
    }

    private var categorySubtitle: String {
        if let c = selectedCategory { return "Showing \(c.label.lowercased())" }
        return "All categories"
    }

    /// Filter as a native Menu - one tap-target instead of a horizontal
    /// pill row. SwiftUI renders this as a system popup on tap, with
    /// checkmarks on the active row.
    private var categoryMenu: some View {
        Menu {
            Button {
                selectedCategory = nil
            } label: {
                Label("All", systemImage: selectedCategory == nil ? "checkmark" : "")
            }
            ForEach(MerchantCategory.allCases.filter { $0 != .other }) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    Label(cat.label, systemImage: selectedCategory == cat ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(selectedCategory?.label ?? "Filter")
            }
            .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
            .padding(.horizontal, DesignTokens.Space.md)
            .padding(.vertical, DesignTokens.Space.xs)
            .background(LocalsTheme.bgElevated)
            .foregroundStyle(LocalsTheme.fg)
            .clipShape(Capsule())
        }
    }

    private var list: some View {
        Group {
            if loading && nearby.isEmpty {
                ProgressView().padding(DesignTokens.Space.xl)
            } else if filtered.isEmpty {
                VStack(spacing: DesignTokens.Space.sm) {
                    Text("No businesses in this category")
                        .font(LocalsTheme.serif(DesignTokens.Size.lg, italic: true))
                    Text("Try All, or scroll the map.")
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .foregroundStyle(LocalsTheme.fgMuted)
                }
                .padding(DesignTokens.Space.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { m in
                            NearbyRow(merchant: m, focused: focusedMerchantId == m.id) {
                                tapRow(m)
                            }
                            Divider().background(LocalsTheme.borderSubtle)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Clustering

    /// Group merchants into clusters by screen-pixel distance. Two
    /// merchants are in the same cluster when their map coordinates fall
    /// within `clusterRadius` of each other at the current zoom level.
    /// Greedy O(n^2) is fine at v1 sizes (<=200 merchants in view).
    private var clusters: [MerchantCluster] {
        let radiusDeg = visibleSpan.latitudeDelta / 18  // tighter as you zoom in
        var groups: [MerchantCluster] = []
        for m in filtered {
            let coord = coordinate(for: m)
            if let i = groups.firstIndex(where: { hypot($0.coordinate.latitude - coord.latitude, $0.coordinate.longitude - coord.longitude) < radiusDeg }) {
                groups[i].merchants.append(m)
                groups[i].coordinate = centroid(groups[i].merchants.map { coordinate(for: $0) })
            } else {
                groups.append(MerchantCluster(id: m.id, coordinate: coord, merchants: [m]))
            }
        }
        return groups
    }

    private func centroid(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else { return visibleCenter }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lng = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Approximate a merchant coordinate from its distance + user's
    /// location. The merchants_near RPC returns distance_m but not raw
    /// lat/lng (the geo column is gated by RLS). We fan annotations out
    /// around the user via a deterministic hash-based bearing - same id
    /// always lands at the same point so the map is stable across reloads.
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

    // MARK: - Interactions

    private func tapRow(_ m: MerchantNear) {
        Haptics.tap()
        focusedMerchantId = m.id
        let target = coordinate(for: m)
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: target,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            sheetDetent = .height(96)
        }
    }

    private func tapPin(_ m: MerchantNear) {
        Haptics.tap()
        if focusedMerchantId == m.id {
            // Second tap on the same pin opens detail.
            pushedSlug = m.slug
        } else {
            focusedMerchantId = m.id
            withAnimation(.easeInOut(duration: 0.25)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate(for: m),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        }
    }

    private func zoomTo(_ cluster: MerchantCluster) {
        Haptics.tap()
        let coords = cluster.merchants.map(coordinate(for:))
        let latMin = coords.map(\.latitude).min()!
        let latMax = coords.map(\.latitude).max()!
        let lngMin = coords.map(\.longitude).min()!
        let lngMax = coords.map(\.longitude).max()!
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.003, (latMax - latMin) * 1.4),
            longitudeDelta: max(0.003, (lngMax - lngMin) * 1.4)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(MKCoordinateRegion(center: cluster.coordinate, span: span))
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

// MARK: - Cluster model

struct MerchantCluster: Identifiable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var merchants: [MerchantNear]
}

// MARK: - Subviews

struct NearbyRow: View {
    let merchant: MerchantNear
    let focused: Bool
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
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(merchant.distanceLabel)
                        .font(LocalsTheme.mono(DesignTokens.Size.xs))
                        .foregroundStyle(LocalsTheme.fgMuted)
                    if focused {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(LocalsTheme.accent)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Space.lg)
            .padding(.vertical, DesignTokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused ? LocalsTheme.bgElevated : LocalsTheme.bg)
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
    let focused: Bool
    var body: some View {
        Text(merchant.name)
            .font(LocalsTheme.body(DesignTokens.Size.xs, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, DesignTokens.Space.sm)
            .padding(.vertical, 5)
            .background(MerchantTheme.background(for: merchant.theme_color))
            .foregroundStyle(MerchantTheme.foreground(for: merchant.theme_color))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    focused ? LocalsTheme.accent : LocalsTheme.fg.opacity(0.5),
                    lineWidth: focused ? 2 : 0.5
                )
            )
            .scaleEffect(focused ? 1.08 : 1.0)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .animation(.easeInOut(duration: 0.2), value: focused)
    }
}

struct ClusterPin: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .bold))
            .foregroundStyle(LocalsTheme.onAccent)
            .frame(width: 38, height: 38)
            .background(LocalsTheme.accent)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}
