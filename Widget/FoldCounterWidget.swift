import SwiftUI
import WidgetKit

private struct CounterEntry: TimelineEntry {
    let date: Date
    let archive: CounterArchive?
    let preview: Bool
}

private struct CounterProvider: TimelineProvider {
    func placeholder(in context: Context) -> CounterEntry {
        CounterEntry(date: .now, archive: nil, preview: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
        completion(CounterEntry(date: .now, archive: readArchive(), preview: context.isPreview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
        let now = Date()
        let archive = readArchive()
        let calendar = DayKey.calendar(in: .current)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        // A precomputed midnight entry prevents yesterday's total from being labeled today.
        // These are snapshot presentations, never background sensor observations.
        let entries = [CounterEntry(date: now, archive: archive, preview: false),
                       CounterEntry(date: tomorrow, archive: archive, preview: false)]
        completion(Timeline(entries: entries, policy: .after(tomorrow.addingTimeInterval(60))))
    }
    private func readArchive() -> CounterArchive? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "FoldCounterAppGroup") as? String,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        // Read only. A missing/corrupt snapshot means unavailable, not a fabricated zero.
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("widget-v1.json")) else { return nil }
        return try? ArchiveFile.decode(data)
    }
}

private struct CounterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CounterEntry

    var body: some View {
        let summary = entry.archive?.summary(now: entry.date, timeZone: .current)
        VStack(alignment: .leading, spacing: family == .accessoryRectangular ? 2 : 8) {
            Label("Fold Counter", systemImage: "rectangle.split.2x1")
                .font(.caption.weight(.semibold))
            if let summary {
                Text(summary.today.formatted())
                    .font(.system(family == .accessoryRectangular ? .title2 : .largeTitle,
                                  design: .rounded, weight: .semibold))
                    .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                Text("Recorded today").font(.caption).foregroundStyle(.secondary)
                if family == .systemMedium {
                    Text("\(summary.total) all-time · \(summary.dailyAverage.formatted(.number.precision(.fractionLength(1)))) daily average")
                        .font(.caption)
                }
            } else {
                Text(entry.preview ? "Your recorded opens" : "Open the app to set up")
                    .font(.headline)
            }
            if family != .accessoryRectangular {
                Text("Saved totals, not live tracking").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "foldcounter://today"))
    }
}

@main
struct FoldCounterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FoldCounterWidget", provider: CounterProvider()) { entry in
            CounterWidgetView(entry: entry)
        }
        .configurationDisplayName("Recorded opens")
        .description("See saved opening counts. The widget does not track folds in the background.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
