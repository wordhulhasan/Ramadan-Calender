import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot = DashboardSnapshot.placeholder
    @Published var isLoading = false
    @Published var statusMessage: String?

    private let locationService = LocationService()
    private var liveTimer: Timer?
    private var activeLocation: CLLocation?
    private var activeSchedule: PrayerSchedule?
    private var activeLocationName = "Finding your location..."
    private var activeDayKey = ""
    private var hasStarted = false

    init() {
        locationService.onLocation = { [weak self] location in
            guard let self else { return }
            Task {
                await self.loadDashboard(for: location)
            }
        }

        locationService.onFailure = { [weak self] message in
            guard let self else { return }
            Task { @MainActor in
                self.isLoading = false
                self.statusMessage = message
            }
        }
    }

    deinit {
        liveTimer?.invalidate()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshLocation()
    }

    func refreshLocation() {
        isLoading = true
        statusMessage = nil
        locationService.requestLocationUpdate()
    }

    private func loadDashboard(for location: CLLocation) async {
        do {
            async let resolvedName = reverseGeocode(location)
            let schedule = try await PrayerAPIService.fetchSchedule(for: location.coordinate)
            let locationName = (try? await resolvedName) ?? fallbackLocationLabel(for: location)

            activeLocation = location
            activeSchedule = schedule
            activeLocationName = locationName
            activeDayKey = Self.dayKey(for: .now)
            statusMessage = nil
            isLoading = false

            rebuildSnapshot(now: .now)
            startLiveTimer()
        } catch {
            isLoading = false
            statusMessage = error.localizedDescription
        }
    }

    private func startLiveTimer() {
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleTick()
            }
        }
    }

    private func handleTick() {
        let now = Date()
        let currentDayKey = Self.dayKey(for: now)

        if currentDayKey != activeDayKey, let activeLocation {
            activeDayKey = currentDayKey
            isLoading = true
            Task {
                await loadDashboard(for: activeLocation)
            }
            return
        }

        rebuildSnapshot(now: now)
    }

    private func rebuildSnapshot(now: Date) {
        guard let schedule = activeSchedule else { return }

        let ramadan = Self.makeRamadanSnapshot(referenceDate: now)
        let prayerStatus = Self.makePrayerWindowStatus(schedule: schedule, now: now)

        snapshot = Self.makeSnapshot(
            schedule: schedule,
            prayerStatus: prayerStatus,
            ramadan: ramadan,
            locationName: activeLocationName,
            now: now
        )
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> String {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            return fallbackLocationLabel(for: location)
        }

        let pieces = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        return pieces.isEmpty ? fallbackLocationLabel(for: location) : pieces.joined(separator: ", ")
    }

    private func fallbackLocationLabel(for location: CLLocation) -> String {
        "\(location.coordinate.latitude.formatted(.number.precision(.fractionLength(2)))), \(location.coordinate.longitude.formatted(.number.precision(.fractionLength(2))))"
    }

    private static func makeSnapshot(
        schedule: PrayerSchedule,
        prayerStatus: PrayerWindowStatus,
        ramadan: RamadanSnapshot,
        locationName: String,
        now: Date
    ) -> DashboardSnapshot {
        let hijriText = "\(schedule.today.date.hijri.day) \(schedule.today.date.hijri.month.en) \(schedule.today.date.hijri.year) AH"
        let currentCountdown = countdownString(to: prayerStatus.currentEndsAt, from: now)
        let nextCountdown = countdownString(to: prayerStatus.nextStartsAt, from: now)
        let suhoorAt = prayerStatus.moments[.imsak] ?? now
        let fajrAt = prayerStatus.moments[.fajr] ?? now
        let iftarAt = prayerStatus.moments[.maghrib] ?? now
        let suhoorCountdown = countdownString(to: suhoorAt, from: now)
        let iftarCountdown = countdownString(to: iftarAt, from: now)

        let suhoorDetail: String
        if now < suhoorAt {
            suhoorDetail = "Suhoor closes in \(suhoorCountdown). Fajr begins at \(formatTime(fajrAt, relativeTo: now))."
        } else {
            suhoorDetail = "Suhoor has ended for today. Fajr began at \(formatTime(fajrAt, relativeTo: now))."
        }

        let iftarDetail: String
        if now < iftarAt {
            iftarDetail = "Iftar begins in \(iftarCountdown) at Maghrib."
        } else {
            iftarDetail = "Iftar began at \(formatTime(iftarAt, relativeTo: now))."
        }

        let currentDetail: String
        if prayerStatus.currentTitle == "Between prayers" {
            currentDetail = "No active fard window right now. \(prayerStatus.nextTitle) starts in \(nextCountdown)."
        } else {
            currentDetail = "\(prayerStatus.currentNote) This waqt ends in \(currentCountdown)."
        }

        let nextDetail = "\(prayerStatus.nextTitle) begins in \(nextCountdown) at \(formatTime(prayerStatus.nextStartsAt, relativeTo: now))."

        let timelineEntries = PrayerEvent.allCases.map { event in
            let eventTime = prayerStatus.moments[event] ?? prayerStatus.tomorrowFajr
            let state: TimelineState

            if prayerStatus.highlightCurrentEvent == event {
                state = .current
            } else if prayerStatus.highlightNextEvent == event {
                state = .next
            } else if now > eventTime {
                state = .past
            } else {
                state = .upcoming
            }

            let detail = event == .isha
                ? "Night prayer continues until \(formatTime(prayerStatus.tomorrowFajr, relativeTo: now))."
                : event.timelineDescription

            return PrayerTimelineEntry(
                prayer: event,
                timeText: formatTime(eventTime, relativeTo: now, allowTomorrowLabel: false),
                detail: detail,
                state: state
            )
        }

        let ramadanHeadline: String
        let ramadanSubtitle: String
        if ramadan.isCurrentRamadan {
            ramadanHeadline = "Day \(ramadan.todayHijriDay)"
            ramadanSubtitle = "Ramadan \(ramadan.todayHijriYear) AH is active and today is highlighted below."
        } else {
            ramadanHeadline = ramadan.todayHijriFormatted
            ramadanSubtitle = "Today is outside Ramadan, so the next Ramadan month is previewed below."
        }

        let insightText: String
        if ramadan.isCurrentRamadan {
            insightText = "Today is day \(ramadan.todayHijriDay) of Ramadan \(ramadan.todayHijriYear) AH. Suhoor closes at \(formatTime(suhoorAt, relativeTo: now)), Iftar opens at \(formatTime(iftarAt, relativeTo: now)), and \(prayerStatus.nextTitle) is the next prayer to watch."
        } else {
            insightText = "Today is \(ramadan.todayHijriFormatted). The app still tracks live prayer times for your location and previews the next Ramadan month below."
        }

        return DashboardSnapshot(
            locationName: locationName,
            gregorianText: gregorianFormatter.string(from: now),
            hijriText: hijriText,
            ramadanHeadline: ramadanHeadline,
            ramadanSubtitle: ramadanSubtitle,
            ramadanMonthTitle: "Ramadan \(ramadan.targetYear) AH",
            ramadanMonthTag: ramadan.isCurrentRamadan ? "Today is in Ramadan" : "Previewing the next Ramadan",
            timelineCaption: prayerStatus.currentTitle == "Between prayers" ? "Waiting for Dhuhr" : "\(prayerStatus.currentTitle) is active",
            insightText: insightText,
            statusChip: ramadan.isCurrentRamadan ? "Ramadan Live" : "Prayer Live",
            cards: [
                DashboardCard(
                    id: "suhoor",
                    eyebrow: "Fasting",
                    title: "Suhoor / Sehri Ends",
                    value: formatTime(suhoorAt, relativeTo: now),
                    detail: suhoorDetail,
                    badge: ramadan.isCurrentRamadan ? "Ramadan Live" : "Prayer Live",
                    symbol: "moon.stars.fill",
                    tone: .emerald
                ),
                DashboardCard(
                    id: "iftar",
                    eyebrow: "Fasting",
                    title: "Iftar Begins",
                    value: formatTime(iftarAt, relativeTo: now),
                    detail: iftarDetail,
                    badge: "Today",
                    symbol: "sun.max.fill",
                    tone: .amber
                ),
                DashboardCard(
                    id: "current",
                    eyebrow: "Prayer Window",
                    title: "Current Waqt",
                    value: prayerStatus.currentTitle,
                    detail: currentDetail,
                    badge: "Now",
                    symbol: "clock.badge.checkmark.fill",
                    tone: .mist
                ),
                DashboardCard(
                    id: "next",
                    eyebrow: "Prayer Window",
                    title: "Next Waqt",
                    value: prayerStatus.nextTitle,
                    detail: nextDetail,
                    badge: "Next",
                    symbol: "clock.arrow.circlepath",
                    tone: .sand
                ),
            ],
            timelineEntries: timelineEntries,
            ramadanDays: ramadan.days
        )
    }

    private static func makePrayerWindowStatus(schedule: PrayerSchedule, now: Date) -> PrayerWindowStatus {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        let moments: [PrayerEvent: Date] = [
            .imsak: makeMoment(from: schedule.today.timings.imsak, on: startOfToday),
            .fajr: makeMoment(from: schedule.today.timings.fajr, on: startOfToday),
            .sunrise: makeMoment(from: schedule.today.timings.sunrise, on: startOfToday),
            .dhuhr: makeMoment(from: schedule.today.timings.dhuhr, on: startOfToday),
            .asr: makeMoment(from: schedule.today.timings.asr, on: startOfToday),
            .maghrib: makeMoment(from: schedule.today.timings.maghrib, on: startOfToday),
            .isha: makeMoment(from: schedule.today.timings.isha, on: startOfToday),
        ]

        let fajr = moments[.fajr] ?? startOfToday
        let sunrise = moments[.sunrise] ?? startOfToday
        let dhuhr = moments[.dhuhr] ?? startOfToday
        let asr = moments[.asr] ?? startOfToday
        let maghrib = moments[.maghrib] ?? startOfToday
        let isha = moments[.isha] ?? startOfToday
        let tomorrowFajr = makeMoment(from: schedule.tomorrow.timings.fajr, on: startOfTomorrow)

        if now < fajr {
            return PrayerWindowStatus(
                currentTitle: "Isha",
                currentNote: "Last night's Isha remains open until Fajr.",
                currentEndsAt: fajr,
                nextTitle: "Fajr",
                nextStartsAt: fajr,
                highlightCurrentEvent: nil,
                highlightNextEvent: .fajr,
                moments: moments,
                tomorrowFajr: tomorrowFajr
            )
        }

        if now < sunrise {
            return PrayerWindowStatus(
                currentTitle: "Fajr",
                currentNote: "Fajr is active until sunrise.",
                currentEndsAt: sunrise,
                nextTitle: "Dhuhr",
                nextStartsAt: dhuhr,
                highlightCurrentEvent: .fajr,
                highlightNextEvent: .dhuhr,
                moments: moments,
                tomorrowFajr: tomorrowFajr
            )
        }

        if now < dhuhr {
            return PrayerWindowStatus(
                currentTitle: "Between prayers",
                currentNote: "No active fard prayer window after sunrise until Dhuhr.",
                currentEndsAt: dhuhr,
                nextTitle: "Dhuhr",
                nextStartsAt: dhuhr,
                highlightCurrentEvent: nil,
                highlightNextEvent: .dhuhr,
                moments: moments,
                tomorrowFajr: tomorrowFajr
            )
        }

        if now < asr {
            return PrayerWindowStatus(
                currentTitle: "Dhuhr",
                currentNote: "Dhuhr is active until Asr begins.",
                currentEndsAt: asr,
                nextTitle: "Asr",
                nextStartsAt: asr,
                highlightCurrentEvent: .dhuhr,
                highlightNextEvent: .asr,
                moments: moments,
                tomorrowFajr: tomorrowFajr
            )
        }

        if now < maghrib {
            return PrayerWindowStatus(
                currentTitle: "Asr",
                currentNote: "Asr is active until Maghrib.",
                currentEndsAt: maghrib,
                nextTitle: "Maghrib",
                nextStartsAt: maghrib,
                highlightCurrentEvent: .asr,
                highlightNextEvent: .maghrib,
                moments: moments,
                tomorrowFajr: tomorrowFajr
            )
        }

        if now < isha {
            return PrayerWindowStatus(
                currentTitle: "Maghrib",
                currentNote: "Maghrib is active until Isha begins.",
                currentEndsAt: isha,
                nextTitle: "Isha",
                nextStartsAt: isha,
                highlightCurrentEvent: .maghrib,
                highlightNextEvent: .isha,
                moments: moments,
                tomorrowFajr: tomorrowFajr
            )
        }

        return PrayerWindowStatus(
            currentTitle: "Isha",
            currentNote: "Isha remains open until Fajr tomorrow.",
            currentEndsAt: tomorrowFajr,
            nextTitle: "Fajr",
            nextStartsAt: tomorrowFajr,
            highlightCurrentEvent: .isha,
            highlightNextEvent: nil,
            moments: moments,
            tomorrowFajr: tomorrowFajr
        )
    }

    private static func makeRamadanSnapshot(referenceDate: Date) -> RamadanSnapshot {
        let gregorian = Calendar(identifier: .gregorian)
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let todayHijri = hijriCalendar.dateComponents([.year, .month, .day], from: referenceDate)
        let todayHijriDay = todayHijri.day ?? 1
        let todayHijriYear = todayHijri.year ?? 1447
        let todayHijriMonth = todayHijri.month ?? 1
        let targetYear = todayHijriMonth <= 9 ? todayHijriYear : todayHijriYear + 1
        let todayStart = gregorian.startOfDay(for: referenceDate)
        let searchStart = gregorian.date(byAdding: .day, value: -220, to: todayStart) ?? todayStart

        var days: [RamadanDay] = []
        var collecting = false

        for offset in 0..<700 {
            guard let probe = gregorian.date(byAdding: .day, value: offset, to: searchStart) else { continue }
            let hijri = hijriCalendar.dateComponents([.year, .month, .day], from: probe)
            let isTargetRamadan = hijri.year == targetYear && hijri.month == 9

            if isTargetRamadan {
                collecting = true
                let probeStart = gregorian.startOfDay(for: probe)
                let state: RamadanDayState

                if probeStart == todayStart {
                    state = .today
                } else if probeStart < todayStart {
                    state = .past
                } else {
                    state = .upcoming
                }

                days.append(
                    RamadanDay(
                        hijriDay: hijri.day ?? days.count + 1,
                        gregorian: probe,
                        state: state
                    )
                )
            } else if collecting {
                break
            }
        }

        return RamadanSnapshot(
            isCurrentRamadan: todayHijriMonth == 9,
            todayHijriDay: todayHijriDay,
            todayHijriYear: todayHijriYear,
            todayHijriFormatted: hijriFormatter.string(from: referenceDate),
            targetYear: targetYear,
            days: days
        )
    }

    private static func makeMoment(from timeString: String, on day: Date) -> Date {
        let pieces = timeString.split(separator: ":")
        let hour = Int(pieces.first ?? "0") ?? 0
        let minute = Int(pieces.dropFirst().first ?? "0") ?? 0
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func countdownString(to targetDate: Date, from now: Date) -> String {
        let seconds = max(0, Int(targetDate.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours == 0 && minutes == 0 {
            return "under a minute"
        }

        if hours == 0 {
            return "\(minutes)m"
        }

        if minutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(minutes)m"
    }

    private static func formatTime(_ date: Date, relativeTo now: Date, allowTomorrowLabel: Bool = true) -> String {
        if allowTomorrowLabel, !Calendar.current.isDate(date, inSameDayAs: now) {
            return tomorrowTimeFormatter.string(from: date)
        }

        return timeFormatter.string(from: date)
    }

    private static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }
}

private let gregorianFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEEE, MMMM d, yyyy"
    return formatter
}()

private let hijriFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMMM y G"
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
}()

private let tomorrowTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE h:mm a"
    return formatter
}()

private let dayKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
