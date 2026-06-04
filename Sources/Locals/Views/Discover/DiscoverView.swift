import SwiftUI
import MapKit
import CoreLocation

/// Discover - the customer surface. Edge-to-edge MapKit with native
/// controls in the safe area, a custom in-ZStack draggable sheet that
/// sits BELOW the tab bar (so the tab bar stays visible above it), and
/// distance-based clustering so busy regions read as a few clean
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
    @State private var focusedMerchantId: UUID?

    // Sheet height as a fraction of available vertical space.
    @State private var sheetFraction: CGFloat = 0.4
    @State private var dragAnchor: CGFloat = 0.4

    private let detents: [CGFloat] = [0.12, 0.4, 0.9]

    var filtered: [MerchantNear] {
        guard let c = selectedCategory else { return nearby }
        return nearby.filter { $0.resolvedCategory == c }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let available = geo.size.height
                let sheetHeight = max(96, available * sheetFraction)

                ZStack(alignment: .bottom) {
                    map
                        .ignoresSafeArea()
                        .overlay(alignment: .topTrailing) { topControls }

                    bottomSheet
                        .frame(height: sheetHeight)
                        .frame(maxWidth: .infinity)
                        .background(LocalsTheme.bg)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: DesignTokens.Radius.xxl,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: DesignTokens.Radius.xxl,
                                style: .continuous
                            )
                        )
                        .shadow(color: .black.opacity(0.12), radius: 18, y: -6)
                        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.85), value: sheetFraction)
                }
            }
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
        .tint(LocalsTheme.userPin)  // overrides the global mustard for the user dot
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
                    .foregroundStyle(LocalsTheme.userPin)
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
            grabberArea
            header
                .padding(.horizontal, DesignTokens.Space.lg)
                .padding(.bottom, DesignTokens.Space.md)
            Divider().background(LocalsTheme.borderSubtle)
            list
        }
    }

    /// Grabber sits inside its own padded zone so the touch target is
    /// large + visually breathable. The whole strip is the drag handle.
    private var grabberArea: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(LocalsTheme.borderSubtle)
                .frame(width: 40, height: 5)
                .padding(.vertical, DesignTokens.Space.md)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Drag up = larger sheet. Translation comes in points; convert
                // to a delta over screen height (~800pt baseline) and apply.
                let delta = -value.translation.height / 800
                sheetFraction = max(0.05, min(0.95, dragAnchor + delta))
            }
            .onEnded { _ in
                // Snap to the nearest detent.
                let snapped = detents.min(by: { abs($0 - sheetFraction) < abs($1 - sheetFraction) }) ?? 0.4
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    sheetFraction = snapped
                }
                dragAnchor = snapped
                Haptics.tap(.light)
            }
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

    private var clusters: [MerchantCluster] {
        let radiusDeg = visibleSpan.latitudeDelta / 18
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
            sheetFraction = 0.12
            dragAnchor = 0.12
        }
    }

    private func tapPin(_ m: MerchantNear) {
        Haptics.tap()
        if focusedMerchantId == m.id {
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
