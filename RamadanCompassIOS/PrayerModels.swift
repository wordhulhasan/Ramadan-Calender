import Foundation

struct PrayerEnvelope: Decodable {
    let data: PrayerDay
}

struct PrayerDay: Decodable {
    let timings: PrayerTimings
    let date: PrayerDateInfo
}

struct PrayerTimings: Decodable {
    let imsak: String
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String

    enum CodingKeys: String, CodingKey {
        case imsak = "Imsak"
        case fajr = "Fajr"
        case sunrise = "Sunrise"
        case dhuhr = "Dhuhr"
        case asr = "Asr"
        case maghrib = "Maghrib"
        case isha = "Isha"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imsak = Self.clean(try container.decode(String.self, forKey: .imsak))
        fajr = Self.clean(try container.decode(String.self, forKey: .fajr))
        sunrise = Self.clean(try container.decode(String.self, forKey: .sunrise))
        dhuhr = Self.clean(try container.decode(String.self, forKey: .dhuhr))
        asr = Self.clean(try container.decode(String.self, forKey: .asr))
        maghrib = Self.clean(try container.decode(String.self, forKey: .maghrib))
        isha = Self.clean(try container.decode(String.self, forKey: .isha))
    }

    func string(for event: PrayerEvent) -> String {
        switch event {
        case .imsak:
            return imsak
        case .fajr:
            return fajr
        case .sunrise:
            return sunrise
        case .dhuhr:
            return dhuhr
        case .asr:
            return asr
        case .maghrib:
            return maghrib
        case .isha:
            return isha
        }
    }

    private static func clean(_ rawValue: String) -> String {
        String(rawValue.split(separator: " ").first ?? Substring(rawValue))
    }
}

struct PrayerDateInfo: Decodable {
    let hijri: HijriDateInfo
}

struct HijriDateInfo: Decodable {
    let day: String
    let year: String
    let month: HijriMonthInfo
}

struct HijriMonthInfo: Decodable {
    let en: String
}

struct PrayerSchedule {
    let today: PrayerDay
    let tomorrow: PrayerDay
}

enum PrayerEvent: String, CaseIterable, Identifiable {
    case imsak
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .imsak:
            return "Suhoor Cut-off"
        case .fajr:
            return "Fajr"
        case .sunrise:
            return "Sunrise"
        case .dhuhr:
            return "Dhuhr"
        case .asr:
            return "Asr"
        case .maghrib:
            return "Maghrib / Iftar"
        case .isha:
            return "Isha"
        }
    }

    var timelineDescription: String {
        switch self {
        case .imsak:
            return "Last moment before the fasting day fully begins."
        case .fajr:
            return "Starts the fasting day and the first fard prayer window."
        case .sunrise:
            return "Fajr ends at sunrise."
        case .dhuhr:
            return "The midday prayer window opens."
        case .asr:
            return "The late afternoon prayer window opens."
        case .maghrib:
            return "Iftar opens at Maghrib."
        case .isha:
            return "Night prayer continues until Fajr tomorrow."
        }
    }
}

enum TimelineState {
    case past
    case current
    case next
    case upcoming
}

struct PrayerTimelineEntry: Identifiable {
    let prayer: PrayerEvent
    let timeText: String
    let detail: String
    let state: TimelineState

    var id: String { prayer.id }
}

enum CardTone {
    case emerald
    case amber
    case mist
    case sand
}

struct DashboardCard: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let value: String
    let detail: String
    let badge: String
    let symbol: String
    let tone: CardTone
}

enum RamadanDayState {
    case past
    case today
    case upcoming
}

struct RamadanDay: Identifiable {
    let hijriDay: Int
    let gregorian: Date
    let state: RamadanDayState

    var id: Int { hijriDay }
}

struct RamadanSnapshot {
    let isCurrentRamadan: Bool
    let todayHijriDay: Int
    let todayHijriYear: Int
    let todayHijriFormatted: String
    let targetYear: Int
    let days: [RamadanDay]
}

struct PrayerWindowStatus {
    let currentTitle: String
    let currentNote: String
    let currentEndsAt: Date
    let nextTitle: String
    let nextStartsAt: Date
    let highlightCurrentEvent: PrayerEvent?
    let highlightNextEvent: PrayerEvent?
    let moments: [PrayerEvent: Date]
    let tomorrowFajr: Date
}

struct DashboardSnapshot {
    let locationName: String
    let gregorianText: String
    let hijriText: String
    let ramadanHeadline: String
    let ramadanSubtitle: String
    let ramadanMonthTitle: String
    let ramadanMonthTag: String
    let timelineCaption: String
    let insightText: String
    let statusChip: String
    let cards: [DashboardCard]
    let timelineEntries: [PrayerTimelineEntry]
    let ramadanDays: [RamadanDay]

    static let placeholder = DashboardSnapshot(
        locationName: "Finding your location...",
        gregorianText: "Loading date...",
        hijriText: "Loading Hijri date...",
        ramadanHeadline: "Checking...",
        ramadanSubtitle: "Preparing your Ramadan dashboard...",
        ramadanMonthTitle: "Loading Ramadan month...",
        ramadanMonthTag: "Loading...",
        timelineCaption: "Loading...",
        insightText: "Waiting for prayer and location data...",
        statusChip: "Live",
        cards: [
            DashboardCard(
                id: "suhoor",
                eyebrow: "Fasting",
                title: "Suhoor / Sehri Ends",
                value: "--:--",
                detail: "Waiting for prayer data...",
                badge: "Live",
                symbol: "moon.stars.fill",
                tone: .emerald
            ),
            DashboardCard(
                id: "iftar",
                eyebrow: "Fasting",
                title: "Iftar Begins",
                value: "--:--",
                detail: "Waiting for prayer data...",
                badge: "Today",
                symbol: "sun.max.fill",
                tone: .amber
            ),
            DashboardCard(
                id: "current",
                eyebrow: "Prayer Window",
                title: "Current Waqt",
                value: "Loading...",
                detail: "Calculating active prayer time...",
                badge: "Now",
                symbol: "clock.badge.checkmark.fill",
                tone: .mist
            ),
            DashboardCard(
                id: "next",
                eyebrow: "Prayer Window",
                title: "Next Waqt",
                value: "Loading...",
                detail: "Calculating what comes next...",
                badge: "Next",
                symbol: "clock.arrow.circlepath",
                tone: .sand
            ),
        ],
        timelineEntries: [],
        ramadanDays: []
    )
}
