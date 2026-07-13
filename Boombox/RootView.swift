import SwiftData
import SwiftUI

/// Hosts the listener wall plus the quiet corner gear that opens parent mode
/// after a two-second hold and a PIN.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var music = MusicService()
    @State private var playback = PlaybackService()
    @State private var speech = SpeechManager()
    @State private var metrics = MetricsLogger()
    @State private var schedule = ScheduleService()
    @State private var settings: AppSettings?
    @State private var showParentArea = false
    @State private var gearHoldProgress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let settings {
                MusicWallView(settings: settings) {
                    showParentArea = true
                }
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
            gearButton
        }
        .environment(music)
        .environment(playback)
        .environment(speech)
        .environment(metrics)
        .environment(schedule)
        .task {
            if settings == nil {
                settings = AppSettings.fetchOrCreate(in: modelContext)
            }
            metrics.start(context: modelContext, playback: playback)
            metrics.pruneOldEvents()
            schedule.start(speech: speech)
            await music.refreshLibrary()
            await updateWidgetSnapshot()
        }
        .task {
            // Drives quiet hours, the sleep timer, the daily budget, and
            // the almost-done warning.
            while !Task.isCancelled {
                if let settings {
                    schedule.tick(settings: settings)
                }
                try? await Task.sleep(for: .seconds(20))
            }
        }
        .task {
            await music.observeSubscription()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await music.refreshLibrary() }
            }
        }
        .fullScreenCover(isPresented: $showParentArea, onDismiss: {
            Task {
                await music.refreshLibrary()
                await updateWidgetSnapshot()
            }
        }) {
            ParentAreaView()
                .environment(music)
                .environment(playback)
                .environment(schedule)
        }
    }

    private func updateWidgetSnapshot() async {
        guard let settings else { return }
        let tiles = (try? modelContext.fetch(FetchDescriptor<Tile>())) ?? []
        await WidgetSnapshotStore.write(
            tiles: tiles, calmMode: settings.calmMode, music: music)
    }

    /// Visually quiet, responds only to a sustained 2-second hold, so stray
    /// taps do nothing. A generous drift tolerance keeps the hold alive when
    /// the finger wobbles, and a ring fills to show the hold is working.
    /// VoiceOver users can activate it directly.
    private var gearButton: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: gearHoldProgress)
                .stroke(
                    Color.gray.opacity(0.7),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 48, height: 48)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.gray.opacity(0.45))
        }
        .frame(width: 72, height: 72)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 2, maximumDistance: 60) {
            gearHoldProgress = 0
            Haptics.soft()
            showParentArea = true
        } onPressingChanged: { pressing in
            if pressing {
                withAnimation(.linear(duration: 2)) {
                    gearHoldProgress = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    gearHoldProgress = 0
                }
            }
        }
        .accessibilityLabel("Setup")
        .accessibilityHint("Hold for two seconds")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            showParentArea = true
        }
        .padding(8)
    }
}
