import SwiftUI
import WidgetKit

private struct CounterEntry: TimelineEntry {
    let date: Date
    let count: PeriodCount?
    let preview: Bool
}

private struct CounterProvider: TimelineProvider {
    let period: CounterPeriod

    func placeholder(in context: Context) -> CounterEntry {
        CounterEntry(date: .now, count: nil, preview: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
        let now = Date()
        let count = readArchive()?.count(for: period, now: now, calendar: .current)
        completion(CounterEntry(date: now, count: count, preview: context.isPreview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
        let now = Date()
        let archive = readArchive()
        let dates = CounterSnapshotTimeline.dates(now: now, calendar: .current)
        // Midnight entries re-evaluate day/week/month totals against the same
        // saved snapshot. They never manufacture background observations.
        // Store only this period's small summary in each entry, rather than
        // copying decades of daily history into every serialized timeline entry.
        let entries = dates.map { date in
            CounterEntry(date: date, count: archive?.count(for: period, now: date, calendar: .current), preview: false)
        }
        let refresh = (dates.dropFirst().first ?? now.addingTimeInterval(3_600)).addingTimeInterval(60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
    private func readArchive() -> CounterArchive? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "FoldCounterAppGroup") as? String,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        // Read only. A missing/corrupt snapshot means unavailable, not a fabricated zero.
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("widget-v1.json")) else { return nil }
        return try? ArchiveFile.decode(data)
    }
}

private extension CounterPeriod {
    var kind: String {
        switch self {
        // Keep the existing today widget identifier so installed widgets survive.
        case .today: "FoldCounterWidget"
        case .allTime: "FoldCounterAllTimeWidget"
        case .week: "FoldCounterWeekWidget"
        case .month: "FoldCounterMonthWidget"
        }
    }

    var title: String {
        switch self {
        case .allTime: "All-time openings"
        case .today: "Openings today"
        case .week: "Openings this week"
        case .month: "Openings this month"
        }
    }

    var caption: String {
        switch self {
        case .allTime: "All-time recorded"
        case .today: "Recorded today"
        case .week: "Recorded this week"
        case .month: "Recorded this month"
        }
    }
}

private struct CounterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CounterEntry
    let period: CounterPeriod

    var body: some View {
        let count = entry.count
        VStack(alignment: .leading, spacing: family == .accessoryRectangular ? 2 : 8) {
            Label(family == .accessoryRectangular ? period.caption : "Hinge Counter", systemImage: "rectangle.split.2x1")
                .font(.caption.weight(.semibold))
            if let count {
                Text(count.total.formatted())
                    .font(.system(family == .accessoryRectangular ? .title2 : .largeTitle,
                                  design: .rounded, weight: .semibold))
                    .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                if family != .accessoryRectangular {
                    Text(period.caption).font(.caption).foregroundStyle(.secondary)
                }
                if count.manual > 0 {
                    Text("\(count.manual.formatted()) manual included")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text(entry.preview ? period.title : "Open the app to set up")
                    .font(.headline)
            }
            if family != .accessoryRectangular {
                Text("Saved totals, not live tracking").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: period == .today ? "foldcounter://today" : "foldcounter://history"))
    }
}

@MainActor
private func periodConfiguration(_ period: CounterPeriod) -> some WidgetConfiguration {
    StaticConfiguration(kind: period.kind, provider: CounterProvider(period: period)) { entry in
        CounterWidgetView(entry: entry, period: period)
    }
    .configurationDisplayName(period.title)
    .description("Saved opening counts. Current periods use local dates and your week-start setting. No background hinge tracking or device-lifetime count.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
}

private struct TodayWidget: Widget {
    var body: some WidgetConfiguration { periodConfiguration(.today) }
}

private struct AllTimeWidget: Widget {
    var body: some WidgetConfiguration { periodConfiguration(.allTime) }
}

private struct WeekWidget: Widget {
    var body: some WidgetConfiguration { periodConfiguration(.week) }
}

private struct MonthWidget: Widget {
    var body: some WidgetConfiguration { periodConfiguration(.month) }
}

@main
struct FoldCounterWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        AllTimeWidget()
        WeekWidget()
        MonthWidget()
    }
}
