import Foundation
import Combine
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published var userLatitude: Double? = nil
    @Published var userLongitude: Double? = nil
    @Published var locationName: String = "Nearby"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // User-picked location shared across views (e.g. set on the Browse page,
    // read by the Map page so the map can auto-center on the entered location).
    @Published var selectedLatitude: Double? = nil
    @Published var selectedLongitude: Double? = nil
    @Published var selectedLocationName: String? = nil

    private let manager = CLLocationManager()

    func setSelectedLocation(name: String, lat: Double, lon: Double) {
        DispatchQueue.main.async {
            self.selectedLatitude = lat
            self.selectedLongitude = lon
            self.selectedLocationName = name
        }
    }

    func clearSelectedLocation() {
        DispatchQueue.main.async {
            self.selectedLatitude = nil
            self.selectedLongitude = nil
            self.selectedLocationName = nil
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocationIfNeeded() {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // startUpdatingLocation continuously listens for location changes.
            // Calling it multiple times is safe — CLLocationManager just keeps monitoring.
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.userLatitude = location.coordinate.latitude
            self.userLongitude = location.coordinate.longitude
        }

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""
                    if !city.isEmpty {
                        self?.locationName = !state.isEmpty ? "\(city), \(state)" : city
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
