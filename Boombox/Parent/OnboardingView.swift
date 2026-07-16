import MusicKit
import SwiftUI
import UIKit

/// First-run setup for the caregiver. Primes music permission, raises the
/// volume-safety step Apple can't do for us, and — importantly — frames the
/// wall as *theirs*: their words, their photos. Shown once, on first entry
/// to Setup, then never again.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(MusicService.self) private var music
    @State private var step = 0

    private var lastStep: Int { 3 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if step < lastStep {
                    Button("Skip") { onFinish() }
                        .padding()
                }
            }

            TabView(selection: $step) {
                welcome.tag(0)
                permission.tag(1)
                volume.tag(2)
                makeItTheirs.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: step)

            Button(step == lastStep ? "Add the first tile" : "Continue") {
                if step == lastStep {
                    onFinish()
                } else {
                    withAnimation { step += 1 }
                }
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.15)))
            .padding(24)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Pages

    private func page<Content: View>(
        icon: String, title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            content()
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var welcome: some View {
        page(icon: "music.note.house.fill", title: "Welcome to Boombox") {
            Text("A wall of big buttons, each one playing music they love. You set it up here; they just tap and listen.")
        }
    }

    private var permission: some View {
        page(icon: "music.note", title: "Connect Apple Music") {
            VStack(spacing: 16) {
                Text("Boombox plays from the Apple Music on this phone. Allow access so you can add playlists.")
                switch music.authStatus {
                case .authorized:
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notDetermined:
                    Button("Allow Apple Music") {
                        Task { await music.requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                default:
                    Link(
                        "Open Settings to allow",
                        destination: URL(string: UIApplication.openSettingsURLString)!)
                }
            }
        }
    }

    private var volume: some View {
        page(icon: "ear", title: "Protect their hearing") {
            Text("Boombox can't limit how loud the phone gets — but iOS can. Turn on Settings › Sounds & Haptics › Headphone Safety › Reduce Loud Sounds. Please do this before handing over the phone.")
        }
    }

    private var makeItTheirs: some View {
        page(icon: "heart.fill", title: "Make it theirs") {
            VStack(alignment: .leading, spacing: 14) {
                tip("Use their words for labels and spoken names — “dragon music,” not “Imagine Dragons.”")
                tip("Use photos they recognise — a favourite singer's face, or a person they love.")
                tip("Start with just a few tiles. You can always add more.")
            }
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(text)
                .multilineTextAlignment(.leading)
        }
    }
}
