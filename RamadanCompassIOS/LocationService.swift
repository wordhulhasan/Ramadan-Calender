import CoreLocation
import Foundation

enum LocationServiceError: LocalizedError {
    case permissionDenied
    case missingLocation

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is required to load accurate local prayer times. Allow it in Settings and refresh."
        case .missingLocation:
            return "Unable to determine your location right now. Try refreshing again."
        }
    }
}

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onLocation: ((CLLocation) -> Void)?
    var onFailure: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocationUpdate() {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            onFailure?(LocationServiceError.permissionDenied.localizedDescription)
        @unknown default:
            onFailure?(LocationServiceError.missingLocation.localizedDescription)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            onFailure?(LocationServiceError.permissionDenied.localizedDescription)
        case .notDetermined:
            break
        @unknown default:
            onFailure?(LocationServiceError.missingLocation.localizedDescription)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            onFailure?(LocationServiceError.missingLocation.localizedDescription)
            return
        }

        onLocation?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onFailure?(error.localizedDescription)
    }
}
