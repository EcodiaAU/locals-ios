import Foundation
import CoreLocation
import Combine

/// Foreground location source. CoreLocation -> @Published coordinate so
/// Discover can centre the map and merchants_near can use a real `(lat, lng)`.
///
/// We default to Sunshine Coast (Maroochydore) when permission is denied or
/// not yet granted - that mirrors the locals-web fallback and lets the
/// Discover screen render real merchants on first launch instead of a
/// permission wall.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var coordinate: CLLocationCoordinate2D
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var hasFix: Bool = false

    static let defaultCoordinate = CLLocationCoordinate2D(latitude: -26.6510, longitude: 153.0667)

    private let manager: CLLocationManager

    override init() {
        self.coordinate = LocationManager.defaultCoordinate
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 30
        authorization = manager.authorizationStatus
    }

    func requestPermissionIfNeeded() {
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            // Denied / restricted - leave the SC fallback in place.
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.coordinate = latest.coordinate
            self.hasFix = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent - the SC fallback is fine. CoreLocation will retry on its own.
    }
}
