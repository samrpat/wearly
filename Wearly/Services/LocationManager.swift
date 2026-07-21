//
//  LocationManager.swift
//  Wearly
//
//  Minimal CoreLocation wrapper: asks permission on demand,
//  publishes the most recent location and the current authorization
//  status so view models can react without touching CoreLocation directly.
//

import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {

    @Published var location: CLLocation?
    /// Human-readable name for `location` — typically the locality
    /// ("Austin"), filled in by reverse geocoding each fix. `nil` until
    /// the first reverse geocode succeeds.
    @Published var locationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermissionAndLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location permission denied."
        @unknown default:
            break
        }
    }

    func refreshLocation() {
        guard manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways else {
            requestPermissionAndLocation()
            return
        }
        manager.requestLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.location = last
            self.errorMessage = nil
            self.reverseGeocode(last)
        }
    }

    /// Best-effort reverse geocode so the header can show a city name.
    /// Quietly leaves `locationName` unchanged on failure — we don't
    /// surface geocoder errors because the weather data already works.
    @MainActor
    private func reverseGeocode(_ loc: CLLocation) {
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            let name = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.administrativeArea
                ?? placemark.name
            Task { @MainActor in self.locationName = name }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
