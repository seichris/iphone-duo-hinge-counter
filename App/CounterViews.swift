import SwiftUI
import Charts

private enum CounterTab: Hashable { case today, history, settings }

struct CounterRootView: View {
    @Environment(CounterModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var sceneID = UUID()
    @State private var selection = CounterTab.today

    var body: some View {
        @Bindable var model = model
        TabView(selection: $selection) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Today", systemImage: "rectangle.split.2x1") }.tag(CounterTab.today)
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "chart.bar.xaxis") }.tag(CounterTab.history)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(CounterTab.settings)
        }
        .tabViewStyle(.sidebarAdaptable)
        .modifier(DuoHingeObserver(scene: sceneID))
        .onAppear { model.setScene(sceneID, active: scenePhase == .active) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.setScene(sceneID, active: phase == .active)
        }
        .onDisappear { model.setScene(sceneID, active: false) }
        .onOpenURL { url in
            guard url.scheme == "foldcounter" else { return }
            if url.host == "today" { selection = .today }
            if url.host == "history" { selection = .history }
        }
        .alert("Could not complete the action", isPresented: Binding(
            get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } }
        )) { Button("OK", role: .cancel) { model.actionError = nil } }
        message: { Text(model.actionError ?? "") }
    }
}

struct DashboardView: View {
    @Environment(CounterModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var countFontSize = 88.0
    #if DEBUG
    @State private var showManualConfirmation = false
    #endif
    @State private var showDemo = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let archive = model.archive {
                let summary = archive.summary(now: context.date, timeZone: .current)
                AdaptiveDashboard {
                    VStack(spacing: 18) {
                        hero(summary)
                        HStack(alignment: .top, spacing: 14) {
                            MetricCard(title: "All-time recorded", value: summary.total.formatted())
                            MetricCard(title: "Daily average", value: summary.dailyAverage.formatted(
                                .number.precision(.fractionLength(1))))
                        }
                        Text("Since \(archive.startedOn) · Includes manual entries")
                            .font(.caption).foregroundStyle(.secondary)
                        if let error = model.storageError { StorageWarning(message: error) }
                        // A split arrangement may show only its primary content.
                        // Keep the coverage disclosure and actions reachable there.
                        TrackingCard()
                        Button { showDemo = true } label: {
                            Label("Try an unsaved demo", systemImage: "play.circle")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }.buttonStyle(.bordered).accessibilityIdentifier("openDemo")
                    }
                } secondary: {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your last 7 days").font(.headline)
                            HistoryChart(archive: archive, now: context.date, days: 7)
                        }.counterCard()
                    }
                }
            } else {
                VStack(spacing: 20) {
                    ContentUnavailableView("Your saved counts need attention",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text("No data was erased. Retry, or open Settings to export the original file or restore a backup."))
                    StorageWarning(message: model.storageError ?? "The counter could not be loaded.")
                }.padding()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Hinge Counter")
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showManualConfirmation = true } label: {
                    Label("Add manual opening", systemImage: "plus")
                }.disabled(!model.canEdit).accessibilityIdentifier("addManual")
            }
        }
        .confirmationDialog("Add one opening manually?", isPresented: $showManualConfirmation,
                            titleVisibility: .visible) {
            Button("Add manual opening") { model.recordManualOpening() }
                .accessibilityIdentifier("confirmManual")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This entry will be labeled manual, not sensor-observed.")
        }
        #endif
        .sheet(isPresented: $showDemo) { DemoView() }
    }

    private func hero(_ summary: CounterSummary) -> some View {
        VStack(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    heroHeading
                    privacyBadge
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    heroHeading
                    Spacer()
                    privacyBadge
                }
            }
            FoldGlyph(degrees: model.angle ?? 150)
                .frame(width: 116, height: 68).padding(.top, 8)
                .accessibilityHidden(true)
            Text(summary.today.formatted())
                .font(.system(size: countFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.3).lineLimit(1)
                .contentTransition(.numericText())
                .accessibilityIdentifier("todayCount")
                .accessibilityLabel("Recorded opens today")
                .accessibilityValue(summary.today.formatted())
            Text("recorded opens").font(.title3).foregroundStyle(.secondary)
            Text("\(summary.automaticToday) observed · \(summary.manualToday) manual")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider().padding(.top, 8)
            Text(model.angle.map { "Live hinge · \(Int($0.rounded()))°" } ?? "No live hinge reading")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .counterCard()
    }

    private var heroHeading: some View {
        Text("TODAY").font(.caption.weight(.semibold)).tracking(2)
    }

    private var privacyBadge: some View {
        Label("On-device", systemImage: "lock.shield")
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TrackingCard: View {
    @Environment(CounterModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(model.trackingTitle, systemImage: model.hingeDetected == true ? "waveform.path" : "info.circle")
                .font(.headline)
            Text(model.trackingDetail).font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("trackingDisclosure")
            Text("Not a device-lifetime or hinge-health measurement.")
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).counterCard()
    }
}

struct StorageWarning: View {
    @Environment(CounterModel.self) private var model
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Counts are not updating", systemImage: "exclamationmark.triangle").font(.headline)
            Text(message).font(.subheadline)
            Button("Retry save or load") { model.retrySaveOrLoad() }.buttonStyle(.bordered)
        }.counterCard()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit().minimumScaleFactor(0.4).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).counterCard()
    }
}

struct HistoryChart: View {
    let archive: CounterArchive
    let now: Date
    let days: Int?

    var body: some View {
        let series = archive.historySeries(last: days, now: now, timeZone: .current)
        let points = series.points
        VStack(alignment: .leading, spacing: 10) {
            if days == nil {
                Text(series.grouping == .day ? "Daily totals" : (series.grouping == .month ? "Monthly totals" : "Yearly totals"))
                    .font(.subheadline).foregroundStyle(.secondary)
                if points.isEmpty { Text("No openings recorded yet.").font(.subheadline) }
            }
            Chart(points) { point in
                BarMark(x: .value("Date", point.date, unit: series.grouping.calendarComponent), y: .value("Opens", point.automatic))
                    .foregroundStyle(by: .value("Source", "Observed"))
                BarMark(x: .value("Date", point.date, unit: series.grouping.calendarComponent), y: .value("Opens", point.manual))
                    .foregroundStyle(by: .value("Source", "Manual"))
            }
            .chartForegroundStyleScale(["Observed": Color.mint, "Manual": Color.indigo])
            .chartYScale(domain: 0...max(1, points.map(\.total).max() ?? 1))
            .chartXAxis {
                if let days {
                    AxisMarks(values: .stride(by: .day, count: days <= 7 ? 1 : (days <= 30 ? 7 : 14))) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisValueLabel(format: series.grouping == .year ? .dateTime.year() : .dateTime.month(.abbreviated).year())
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Recorded opens, separated into observed and manual counts")
            Text("Zero means no opens recorded, not proof that the phone stayed closed.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct HistoryView: View {
    @Environment(CounterModel.self) private var model
    @State private var range = 30
    @State private var visibleDays = 90

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let archive = model.archive {
                let allHistory = range == 0
                let points = allHistory ? archive.recordedHistory(timeZone: .current, latest: visibleDays)
                    : archive.history(last: range, now: context.date, timeZone: .current)
                List {
                    Section {
                        Picker("Days", selection: $range) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("All").tag(0)
                        }.pickerStyle(.segmented).accessibilityIdentifier("historyRange")
                        HistoryChart(archive: archive, now: context.date, days: allHistory ? nil : range)
                            .padding(.vertical, 8)
                    }
                    Section {
                        ForEach(points.reversed()) { day in
                            HistoryDayRow(day: day)
                        }
                        if allHistory && visibleDays < archive.days.count {
                            Button("Show older days") { visibleDays += 90 }
                                .accessibilityIdentifier("olderHistory")
                        }
                    } header: {
                        Text("Daily breakdown")
                    } footer: {
                        if allHistory {
                            Text("All saved dates, newest first. Days without a saved record are omitted here. "
                                 + "History does not expire after 90 days. Export a JSON backup to keep a separate copy.")
                        }
                    }
                }
                .onChange(of: range) { _, _ in visibleDays = 90 }
            } else {
                ContentUnavailableView("History unavailable", systemImage: "chart.bar",
                    description: Text("Restore access to your data in Settings."))
            }
        }.navigationTitle("History")
    }
}

private struct HistoryDayRow: View {
    let day: HistoryPoint

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.day)
                Text("\(day.automatic) observed · \(day.manual) manual")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(day.total.formatted()).monospacedDigit().font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historyDay-\(day.day)")
    }
}

struct FoldGlyph: View {
    let degrees: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 10).fill(.mint.gradient)
                .rotation3DEffect(.degrees((180 - degrees) * 0.35), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0)
            RoundedRectangle(cornerRadius: 10).fill(.mint.opacity(0.6).gradient)
                .rotation3DEffect(.degrees(-(180 - degrees) * 0.35), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0)
        }.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: degrees)
    }
}

private extension View {
    func counterCard() -> some View {
        padding(20).background(Color(uiColor: .secondarySystemGroupedBackground),
                               in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
