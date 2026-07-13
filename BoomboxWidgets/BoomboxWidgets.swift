import SwiftUI
import WidgetKit

@main
struct BoomboxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BoomboxTilesWidget()
    }
}

struct TilesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct TilesProvider: TimelineProvider {
    /// Shown in the widget gallery before the app has written real data.
    static let sample = WidgetSnapshot(
        calmMode: false,
        tiles: [
            WidgetTile(
                id: UUID(), label: "Dragons", colourID: 6, kind: "emoji", value: "🐉"),
            WidgetTile(
                id: UUID(), label: "Sunshine", colourID: 2, kind: "symbol",
                value: "sun.max.fill"),
            WidgetTile(
                id: UUID(), label: "Dance", colourID: 7, kind: "emoji", value: "💃"),
            WidgetTile(
                id: UUID(), label: "Bedtime", colourID: 4, kind: "symbol",
                value: "moon.stars.fill"),
        ])

    func placeholder(in context: Context) -> TilesEntry {
        TilesEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TilesEntry) -> Void) {
        let snapshot = context.isPreview
            ? (WidgetStore.load() ?? Self.sample)
            : WidgetStore.load()
        completion(TilesEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TilesEntry>) -> Void) {
        // Content only changes when the app rewrites the snapshot; the app
        // calls WidgetCenter.reloadAllTimelines() then.
        let entry = TilesEntry(date: .now, snapshot: WidgetStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct BoomboxTilesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BoomboxTiles", provider: TilesProvider()) { entry in
            TilesWidgetView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("Music Tiles")
        .description("Tap a tile to play its music.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular,
        ])
    }
}
