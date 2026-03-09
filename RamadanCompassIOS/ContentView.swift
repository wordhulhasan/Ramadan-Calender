import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DashboardViewModel()

    private let summaryColumns = [GridItem(.adaptive(minimum: 170), spacing: 16)]
    private let calendarColumns = [GridItem(.adaptive(minimum: 105), spacing: 12)]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroSection

                    if let statusMessage = viewModel.statusMessage {
                        StatusBanner(message: statusMessage)
                    }

                    LazyVGrid(columns: summaryColumns, spacing: 16) {
                        ForEach(viewModel.snapshot.cards) { card in
                            SummaryCard(card: card)
                        }
                    }

                    SectionPanel {
                        sectionHeader(
                            kicker: "Prayer Flow",
                            title: "Today's prayer timeline",
                            tag: viewModel.snapshot.timelineCaption
                        )

                        if viewModel.snapshot.timelineEntries.isEmpty {
                            ProgressPlaceholder(text: "Loading prayer timeline...")
                        } else {
                            VStack(spacing: 14) {
                                ForEach(viewModel.snapshot.timelineEntries) { entry in
                                    PrayerTimelineRow(entry: entry)
                                }
                            }
                        }
                    }

                    SectionPanel {
                        sectionHeader(
                            kicker: "Ramadan Calendar",
                            title: viewModel.snapshot.ramadanMonthTitle,
                            tag: viewModel.snapshot.ramadanMonthTag
                        )

                        if viewModel.snapshot.ramadanDays.isEmpty {
                            ProgressPlaceholder(text: "Loading Ramadan calendar...")
                        } else {
                            LazyVGrid(columns: calendarColumns, spacing: 12) {
                                ForEach(viewModel.snapshot.ramadanDays) { day in
                                    RamadanDayCell(day: day)
                                }
                            }
                        }
                    }

                    SectionPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Prayer Insight")
                                .font(.system(.title2, design: .serif, weight: .semibold))
                                .foregroundStyle(Color.ink)

                            Text(viewModel.snapshot.insightText)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Color.ink.opacity(0.74))
                                .lineSpacing(4)

                            Label("CoreLocation + CLGeocoder + AlAdhan API", systemImage: "network")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.emerald.opacity(0.08), in: Capsule())
                                .foregroundStyle(Color.emerald)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .refreshable {
                viewModel.refreshLocation()
            }
        }
        .task {
            viewModel.start()
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.deepEmerald, Color.emerald, Color.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 130, height: 130)
                        .blur(radius: 8)
                        .offset(x: 34, y: -34)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            ViewThatFits {
                HStack(alignment: .top, spacing: 18) {
                    heroCopy
                    heroSpotlight
                }

                VStack(alignment: .leading, spacing: 18) {
                    heroCopy
                    heroSpotlight
                }
            }
            .padding(22)

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(18)
            }
        }
        .shadow(color: Color.deepEmerald.opacity(0.18), radius: 28, x: 0, y: 18)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Ramadan Companion")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(2.3)
                    .foregroundStyle(Color.white.opacity(0.78))

                Text("Ramadan Compass")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("A native Islamic dashboard that finds your location, tracks today’s Ramadan context, and keeps the current and next prayer windows clear at a glance.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineSpacing(4)
            }

            VStack(spacing: 10) {
                HeroMetaPill(label: "Location", value: viewModel.snapshot.locationName)
                HeroMetaPill(label: "Today", value: viewModel.snapshot.gregorianText)
                HeroMetaPill(label: "Hijri", value: viewModel.snapshot.hijriText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroSpotlight: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ramadan Day")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.8)
                    .foregroundStyle(Color.ink.opacity(0.65))

                Text(viewModel.snapshot.ramadanHeadline)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)

                Text(viewModel.snapshot.ramadanSubtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.ink.opacity(0.7))
                    .lineSpacing(4)
            }

            HStack(spacing: 10) {
                Text(viewModel.snapshot.statusChip)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.emerald.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.emerald)

                Spacer(minLength: 0)

                Button {
                    viewModel.refreshLocation()
                } label: {
                    Label("Refresh", systemImage: "location.circle.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.ink.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ink)
            }
        }
        .padding(18)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 22, x: 0, y: 12)
    }

    @ViewBuilder
    private func sectionHeader(kicker: String, title: String, tag: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kicker)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(Color.ink.opacity(0.55))

                Text(title)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }

            Spacer(minLength: 0)

            Text(tag)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.emerald.opacity(0.08), in: Capsule())
                .foregroundStyle(Color.emerald)
        }
    }
}

private struct SummaryCard: View {
    let card: DashboardCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.eyebrow)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(card.secondaryTextColor)

                    Text(card.title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(card.primaryTextColor)
                }

                Spacer(minLength: 12)

                Image(systemName: card.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(card.iconTint)
                    .padding(11)
                    .background(card.iconBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text(card.value)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(card.primaryTextColor)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            Text(card.detail)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(card.secondaryTextColor)
                .lineSpacing(4)

            Text(card.badge)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(card.badgeBackground, in: Capsule())
                .foregroundStyle(card.badgeForeground)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(card.cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 12)
    }
}

private struct PrayerTimelineRow: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(entry.dotColor)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .stroke(entry.dotColor.opacity(0.28), lineWidth: 10)
                }
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.prayer.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.ink)

                    Text(entry.stateLabel)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.dotColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(entry.dotColor.opacity(0.12), in: Capsule())
                }

                Text(entry.detail)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.ink.opacity(0.68))
                    .lineSpacing(4)
            }

            Spacer(minLength: 12)

            Text(entry.timeText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.ink)
        }
        .padding(14)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RamadanDayCell: View {
    let day: RamadanDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(day.hijriDay)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .frame(width: 42, height: 42)
                .background(numberBackground, in: Circle())
                .foregroundStyle(numberForeground)

            Text(day.gregorian.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(textSecondary)

            Text(day.gregorian.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(textPrimary)

            Text(statusText)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(14)
        .background(cellBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }

    private var statusText: String {
        switch day.state {
        case .past:
            return "Completed day"
        case .today:
            return "Today in Ramadan"
        case .upcoming:
            return "Upcoming day"
        }
    }

    private var cellBackground: AnyShapeStyle {
        switch day.state {
        case .today:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.deepEmerald, Color.emerald],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .past:
            return AnyShapeStyle(Color.white.opacity(0.68))
        case .upcoming:
            return AnyShapeStyle(Color.gold.opacity(0.1))
        }
    }

    private var borderColor: Color {
        switch day.state {
        case .today:
            return .clear
        case .past:
            return Color.ink.opacity(0.06)
        case .upcoming:
            return Color.gold.opacity(0.22)
        }
    }

    private var numberBackground: Color {
        day.state == .today ? Color.white.opacity(0.14) : Color.emerald.opacity(0.09)
    }

    private var numberForeground: Color {
        day.state == .today ? .white : .emerald
    }

    private var textPrimary: Color {
        day.state == .today ? .white : .ink
    }

    private var textSecondary: Color {
        day.state == .today ? .white.opacity(0.82) : .ink.opacity(0.64)
    }
}

private struct HeroMetaPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.72))

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct StatusBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.amberDeep)

            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ink)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.amberDeep.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct ProgressPlaceholder: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.emerald)

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.ink.opacity(0.64))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}

private struct SectionPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(18)
        .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.ink.opacity(0.06), radius: 22, x: 0, y: 12)
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.canvas, Color.softMint, Color.morning],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.gold.opacity(0.28))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: 60, y: -60)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.emerald.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 10)
                .offset(x: -80, y: 80)
        }
        .ignoresSafeArea()
    }
}

private extension DashboardCard {
    var cardBackground: AnyShapeStyle {
        switch tone {
        case .emerald:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.deepEmerald, Color.emerald],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .amber:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.gold.opacity(0.78), Color.sand.opacity(0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .mist:
            return AnyShapeStyle(Color.white.opacity(0.72))
        case .sand:
            return AnyShapeStyle(Color.sand.opacity(0.62))
        }
    }

    var primaryTextColor: Color {
        switch tone {
        case .emerald:
            return .white
        case .amber, .mist, .sand:
            return .ink
        }
    }

    var secondaryTextColor: Color {
        switch tone {
        case .emerald:
            return .white.opacity(0.82)
        case .amber, .mist, .sand:
            return .ink.opacity(0.68)
        }
    }

    var badgeBackground: Color {
        switch tone {
        case .emerald:
            return .white.opacity(0.16)
        case .amber:
            return .amberDeep.opacity(0.14)
        case .mist, .sand:
            return .emerald.opacity(0.10)
        }
    }

    var badgeForeground: Color {
        switch tone {
        case .emerald:
            return .white
        case .amber:
            return .amberDeep
        case .mist, .sand:
            return .emerald
        }
    }

    var iconBackground: Color {
        switch tone {
        case .emerald:
            return .white.opacity(0.12)
        case .amber:
            return .white.opacity(0.55)
        case .mist, .sand:
            return .emerald.opacity(0.08)
        }
    }

    var iconTint: Color {
        switch tone {
        case .emerald:
            return .white
        case .amber:
            return .amberDeep
        case .mist, .sand:
            return .emerald
        }
    }
}

private extension PrayerTimelineEntry {
    var dotColor: Color {
        switch state {
        case .current:
            return .emerald
        case .next:
            return .amberDeep
        case .past:
            return .ink.opacity(0.28)
        case .upcoming:
            return .ink.opacity(0.46)
        }
    }

    var stateLabel: String {
        switch state {
        case .current:
            return "Active now"
        case .next:
            return "Coming next"
        case .past:
            return "Passed"
        case .upcoming:
            return "Upcoming"
        }
    }
}

private extension Color {
    static let canvas = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let morning = Color(red: 0.87, green: 0.93, blue: 0.90)
    static let softMint = Color(red: 0.94, green: 0.97, blue: 0.95)
    static let emerald = Color(red: 0.08, green: 0.43, blue: 0.40)
    static let deepEmerald = Color(red: 0.05, green: 0.29, blue: 0.27)
    static let gold = Color(red: 0.79, green: 0.59, blue: 0.26)
    static let sand = Color(red: 0.98, green: 0.93, blue: 0.84)
    static let amberDeep = Color(red: 0.79, green: 0.43, blue: 0.16)
    static let ink = Color(red: 0.10, green: 0.20, blue: 0.19)
}

#Preview {
    ContentView()
}
