import Charts
import SwiftData
import SwiftUI

/// The parent layer: what has actually been playing back there.
struct MetricsView: View {
    private enum TimeRange: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "7 Days"
        case month = "30 Days"

        var id: String { rawValue }

        var cutoff: Date {
            let calendar = Calendar.current
            switch self {
            case .today: return calendar.startOfDay(for: .now)
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
            case .month:
                return calendar.date(byAdding: .day, value: -30, to: .now) ?? .now
            }
        }
    }

    private struct CountedRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let count: Int
    }

    private struct DailyCount: Identifiable {
        let id: Date
        let day: Date
        let count: Int
    }

    @Query(sort: \PlayEvent.date, order: .reverse) private var events: [PlayEvent]
    @Environment(ScheduleService.self) private var schedule
    @State private var range: TimeRange = .week

    private var filtered: [PlayEvent] {
        let cutoff = range.cutoff
        return events.filter { $0.date >= cutoff && $0.kind != .tapIgnored }
    }

    private var ignoredTapCount: Int {
        let cutoff = range.cutoff
        return events.filter { $0.date >= cutoff && $0.kind == .tapIgnored }.count
    }

    private var loudestVolume: Double? {
        songEvents.compactMap(\.volume).max()
    }

    private var songEvents: [PlayEvent] {
        filtered.filter { $0.kind == .song }
    }

    private var topTiles: [CountedRow] {
        let taps = filtered.filter { $0.kind == .tilePlay }
        let groups = Dictionary(grouping: taps) { $0.tileLabel ?? "Unknown" }
        return groups
            .map { CountedRow(id: $0.key, title: $0.key, subtitle: nil, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var topSongs: [CountedRow] {
        let groups = Dictionary(grouping: songEvents) {
            ($0.songTitle ?? "") + "|" + ($0.artistName ?? "")
        }
        return groups
            .compactMap { key, value -> CountedRow? in
                guard let first = value.first, let title = first.songTitle else { return nil }
                return CountedRow(
                    id: key, title: title, subtitle: first.artistName, count: value.count)
            }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    private var dailyCounts: [DailyCount] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: songEvents) {
            calendar.startOfDay(for: $0.date)
        }
        return groups
            .map { DailyCount(id: $0.key, day: $0.key, count: $0.value.count) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Listening today", value: "\(schedule.todayMinutes) min")
                LabeledContent("Extra touches", value: "\(ignoredTapCount)")
                if let loudestVolume {
                    LabeledContent(
                        "Loudest playback", value: "\(Int(loudestVolume * 100))%")
                }
            } header: {
                Text("Signals")
            } footer: {
                Text("Extra touches are taps the app absorbed because they landed more than once — a rising count means tap acuity is struggling.")
            }

            if filtered.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nothing yet",
                        systemImage: "chart.bar",
                        description: Text("Plays will show up here."))
                }
            } else {
                if range != .today && dailyCounts.count > 1 {
                    Section("Songs per day") {
                        Chart(dailyCounts) { day in
                            BarMark(
                                x: .value("Day", day.day, unit: .day),
                                y: .value("Songs", day.count))
                            .cornerRadius(3)
                        }
                        .frame(height: 160)
                        .padding(.vertical, 8)
                    }
                }

                if !topTiles.isEmpty {
                    Section("Most tapped tiles") {
                        ForEach(topTiles) { row in
                            HStack {
                                Text(row.title)
                                Spacer()
                                Text("\(row.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                if !topSongs.isEmpty {
                    Section("Most played songs") {
                        ForEach(topSongs) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title).lineLimit(1)
                                    if let subtitle = row.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text("\(row.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    ForEach(filtered.prefix(30)) { event in
                        HStack(spacing: 10) {
                            Image(
                                systemName: event.kind == .tilePlay
                                    ? "hand.tap.fill" : "music.note")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                if event.kind == .tilePlay {
                                    Text("Tapped \(event.tileLabel ?? "a tile")")
                                } else {
                                    Text(event.songTitle ?? "Unknown song")
                                        .lineLimit(1)
                                    if let artist = event.artistName {
                                        Text(artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            Spacer()
                            Text(
                                event.date.formatted(
                                    .relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Recent")
                } footer: {
                    Text("Songs are counted while Boombox is open. Tile taps are always counted. History is kept for 90 days.")
                }
            }
        }
        .navigationTitle("Listening")
        .navigationBarTitleDisplayMode(.inline)
    }
}
