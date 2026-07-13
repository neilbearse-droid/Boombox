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
    @State private var settings: AppSettings?
    @State private var showParentArea = false

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
        .task {
            if settings == nil {
                settings = AppSettings.fetchOrCreate(in: modelContext)
            }
            await music.refreshLibrary()
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
            Task { await music.refreshLibrary() }
        }) {
            ParentAreaView()
                .environment(music)
                .environment(playback)
        }
    }

    /// Visually quiet, responds only to a sustained 2-second hold, so stray
    /// taps do nothing. VoiceOver users can activate it directly.
    private var gearButton: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.gray.opacity(0.35))
            .frame(width: 56, height: 56)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 2) {
                showParentArea = true
            }
            .accessibilityLabel("Setup")
            .accessibilityHint("Hold for two seconds")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                showParentArea = true
            }
            .padding(4)
    }
}
