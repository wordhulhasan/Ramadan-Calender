import CoreLocation
import Foundation

enum PrayerAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to create the prayer time request."
        case .invalidResponse:
            return "The prayer time service returned an invalid response."
        case .decodingFailed:
            return "The prayer time service returned unreadable data."
        }
    }
}

enum PrayerAPIService {
    static func fetchSchedule(for coordinate: CLLocationCoordinate2D, now: Date = .now) async throws -> PrayerSchedule {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        async let todayDay = fetchDay(for: now, coordinate: coordinate)
        async let tomorrowDay = fetchDay(for: tomorrow, coordinate: coordinate)
        return PrayerSchedule(today: try await todayDay, tomorrow: try await tomorrowDay)
    }

    private static func fetchDay(for date: Date, coordinate: CLLocationCoordinate2D) async throws -> PrayerDay {
        guard var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(apiDateString(from: date))") else {
            throw PrayerAPIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "method", value: "2"),
        ]

        guard let url = components.url else {
            throw PrayerAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw PrayerAPIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(PrayerEnvelope.self, from: data).data
        } catch {
            throw PrayerAPIError.decodingFailed
        }
    }

    private static func apiDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }
}
