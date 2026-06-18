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

    var filtered: [MerchantNear] {
        guard let c = selectedCategory else { return nearby }
        return nearby.filter { $0.resolvedCategory == c }
    }

    // Sheet height state for the custom in-ZStack bottom view. 0.0 collapses
    // to the peek (chip rail + a few rows visible above the tab bar), 1.0
    // expands to ~85% of the available screen. SwiftUI .sheet() was tried
    // and rejected (2026-06-12 Tate: "the apple one is sitting infront of
    // the bottom tab bar so i cant change tabs") because .sheet covers the
    // TabView's tab pill on iOS 26. The custom sheet stays inside the tab
    // content area, leaving the tab bar visible below at every detent.
    @State private var sheetFraction: CGFloat = 0.0
    @State private var dragAnchor: CGFloat = 0.0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) { topControls }

                // GeometryReader does NOT ignoresSafeArea here, so
                // geo.safeAreaInsets.bottom reports the REAL tab-bar +
                // home-indicator inset. The sheet's material bleeds
                // past that inset to the screen edge via .container
                // ignoresSafeArea; the content above is padded UP by
                // the real inset so chip rail + list clear the tab
                // pill. Pattern lifted from glovebox-ios GBBottomSheet.
                GeometryReader { geo in
                    let bottomInset = geo.safeAreaInsets.bottom
                    let bottomGap: CGFloat = DesignTokens.Space.sm
                    let available = geo.size.height
                    let peek: CGFloat = 188
                    let mediumHeight = max(peek, available * 0.46)
                    let expandedHeight = max(mediumHeight, available * 0.86)
                    let targetHeight = height(for: sheetFraction, peek: peek, medium: mediumHeight, expanded: expandedHeight)
                    let liveHeight = min(expandedHeight, max(peek, targetHeight - dragTranslation))

                    VStack(spacing: 0) {
                        dragHandle
                        chipRail
                            .padding(.horizontal, DesignTokens.Space.lg)
                            .padding(.bottom, DesignTokens.Space.sm)
                        ScrollView {
                            list
                                .padding(.horizontal, DesignTokens.Space.lg)
                                .padding(.bottom, DesignTokens.Space.lg)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollDisabled(sheetFraction < 0.85)
                    }
                    .frame(height: liveHeight, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, bottomInset + bottomGap)
                    .background(
                        .regularMaterial,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: DesignTokens.Radius.xxl,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: DesignTokens.Radius.xxl,
                            style: .continuous
                        )
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: DesignTokens.Radius.xxl,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: DesignTokens.Radius.xxl,
                            style: .continuous
                        )
                    )
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: sheetFraction)
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: liveHeight)
                    .gesture(dragGesture(peek: peek, medium: mediumHeight, expanded: expandedHeight))
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

    @GestureState private var dragTranslation: CGFloat = 0

    private var dragHandle: some View {
        // Generous breathing room above and below the grabber so the sheet
        // top reads as a calm, deliberate surface rather than a cramped lip.
        // (2026-06-18 Tate: "give the discover page more space above and
        // below drag handle to make it feel much nicer.")
        Capsule()
            .fill(Color.gray.opacity(0.35))
            .frame(width: 40, height: 5)
            .padding(.top, DesignTokens.Space.xl)
            .padding(.bottom, DesignTokens.Space.lg)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }

    private func height(for fraction: CGFloat, peek: CGFloat, medium: CGFloat, expanded: CGFloat) -> CGFloat {
        if fraction < 0.25 { return peek }
        if fraction < 0.7 { return medium }
        return expanded
    }

    private func dragGesture(peek: CGFloat, medium: CGFloat, expanded: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let current = height(for: sheetFraction, peek: peek, medium: medium, expanded: expanded)
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let projected = current - value.translation.height - velocity * 0.18
                let candidates: [(CGFloat, CGFloat)] = [
                    (0.0, peek),
                    (0.5, medium),
                    (0.95, expanded)
                ]
                let nearest = candidates.min(by: { abs($0.1 - projected) < abs($1.1 - projected) })?.0 ?? 0.0
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    sheetFraction = nearest
                }
                dragAnchor = nearest
                Haptics.tap(.light)
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
            .accessibilityLabel("Centre map on my location")
        }
        .padding(.horizontal, DesignTokens.Space.md)
        .padding(.top, DesignTokens.Space.sm)
    }

    // MARK: - Sheet content (chip rail + list)

    // Horizontal scrolling chip rail - All + each merchant category.
    // Mirrors locals-android `CategoryRail` 1:1: single primary control,
    // selected chip in ink, unselected in soft gray. Replaces the older
    // header + Filter dropdown which Tate flagged as visually busy.
    private var chipRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Space.sm) {
                chip("All", active: selectedCategory == nil) { selectedCategory = nil }
                ForEach(MerchantCategory.allCases.filter { $0 != .other }) { cat in
                    chip(cat.label, active: selectedCategory == cat) { selectedCategory = cat }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(.light); action() }) {
            Text(label)
                .font(LocalsTheme.body(DesignTokens.Size.sm, weight: .medium))
                .padding(.horizontal, DesignTokens.Space.md)
                .padding(.vertical, DesignTokens.Space.xs)
                .background(active ? LocalsTheme.fg : LocalsTheme.bgSubtle)
                .foregroundStyle(active ? LocalsTheme.bg : LocalsTheme.fg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        Group {
            if loading && nearby.isEmpty {
                HStack { ProgressView(); Spacer() }
            } else if filtered.isEmpty {
                // Left-aligned, plain sans empty state - matches Android's
                // EmptyListBlock. The old centered serif-italic version read
                // as "wack" / over-designed for a simple bottom sheet.
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCategory == nil
                         ? "No merchants here yet"
                         : "No merchants in this category here")
                        .font(LocalsTheme.body(DesignTokens.Size.base, weight: .semibold))
                        .foregroundStyle(LocalsTheme.fg)
                    Text(selectedCategory == nil
                         ? "Locals starts on the Sunshine Coast. We will be in more places soon."
                         : "Try All, or move the map.")
                        .font(LocalsTheme.body(DesignTokens.Size.sm))
                        .foregroundStyle(LocalsTheme.fgMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // No inner ScrollView: the body already wraps `list` in one
                // (gated by .scrollDisabled(sheetFraction < 0.85)). A nested
                // vertical ScrollView here stole the drag gesture and let the
                // list scroll at the peek/medium detents, defeating the
                // drag-to-expand-then-scroll contract. Plain LazyVStack lets
                // the single outer ScrollView own both the drag and the scroll.
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

    // A list row opens the merchant directly - parity with locals-android
    // (DiscoverScreen MerchantCard onClick -> onMerchant(slug)) and the
    // universal expectation for a list of places. The previous behaviour
    // only panned the map, leaving the user to hunt the pin and double-tap
    // it to actually open the page, which read as a dead tap.
    private func tapRow(_ m: MerchantNear) {
        Haptics.tap()
        focusedMerchantId = m.id
        pushedSlug = m.slug
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
