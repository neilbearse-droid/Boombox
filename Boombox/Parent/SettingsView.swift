import SwiftData
import SwiftUI

/// Settings landing screen: a short list of categories that open focused
/// sub-screens, so the caregiver never faces one overwhelming wall of toggles.
struct SettingsView: View {
    @Query private var allSettings: [AppSettings]
    @State private var showChangePIN = false

    var body: some View {
        if let settings = allSettings.first {
            List {
                Section {
                    NavigationLink {
                        WallSettings(settings: settings)
                    } label: {
                        Label("Music Wall", systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        SoundSpeechSettings(settings: settings)
                    } label: {
                        Label("Sound & Speech", systemImage: "speaker.wave.2")
                    }
                    NavigationLink {
                        SeeingHearingSettings(settings: settings)
                    } label: {
                        Label("Seeing & Hearing", systemImage: "eye")
                    }
                    NavigationLink {
                        TouchSettings(settings: settings)
                    } label: {
                        Label("Touch", systemImage: "hand.tap")
                    }
                    NavigationLink {
                        ScheduleSettings(settings: settings)
                    } label: {
                        Label("Schedule & Limits", systemImage: "clock")
                    }
                    NavigationLink {
                        LyricsSettings(settings: settings)
                    } label: {
                        Label("Lyrics", systemImage: "text.quote")
                    }
                    NavigationLink {
                        ContentSettings(settings: settings)
                    } label: {
                        Label("Content", systemImage: "checkmark.shield")
                    }
                }

                Section {
                    Button {
                        showChangePIN = true
                    } label: {
                        Label("Change PIN", systemImage: "lock")
                    }
                    NavigationLink {
                        SetupChecklistView()
                    } label: {
                        Label("Setup Checklist", systemImage: "checklist")
                    }
                }

                Section {
                    NavigationLink {
                        TipJarView()
                    } label: {
                        Label("Support Boombox", systemImage: "heart")
                    }
                } footer: {
                    Text("Boombox is free. Tips are optional and unlock nothing.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showChangePIN) {
                PINGateView(
                    mode: .change,
                    onSuccess: { showChangePIN = false },
                    onCancel: { showChangePIN = false })
            }
        } else {
            ProgressView()
        }
    }
}

// MARK: - Category screens

private struct WallSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Columns", selection: $settings.columns) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                }
                .pickerStyle(.segmented)
                Toggle("Show labels", isOn: $settings.showLabels)
                Picker("Tiles shown", selection: $settings.maxTiles) {
                    Text("All").tag(0)
                    Text("One big tile").tag(1)
                    Text("2").tag(2)
                    Text("4").tag(4)
                }
            } footer: {
                Text("Fewer tiles can help on overwhelming days. Tiles keep their wall order.")
            }
            Section("Now Playing") {
                Toggle("Next Song button", isOn: $settings.showNextButton)
            }
        }
        .navigationTitle("Music Wall")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SoundSpeechSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Spoken confirmations", isOn: $settings.speakOnPlay)
                Picker("Speaking speed", selection: $settings.speechRate) {
                    Text("Normal").tag(1.0)
                    Text("Slower").tag(0.75)
                }
                Picker("Voice", selection: $settings.speechPitch) {
                    Text("Normal").tag(1.0)
                    Text("Plain").tag(0.9)
                }
            } footer: {
                Text("When on, the phone says the tile's spoken name as it starts. Use each tile's own words. A plainer, slower voice suits some adult listeners better.")
            }
        }
        .navigationTitle("Sound & Speech")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SeeingHearingSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Text size", selection: $settings.textScale) {
                    Text("Normal").tag(1.0)
                    Text("Large").tag(1.25)
                    Text("Huge").tag(1.5)
                }
                Toggle("High-contrast tiles", isOn: $settings.highContrastTiles)
                Picker("Dim screen", selection: $settings.screenDim) {
                    Text("Off").tag(0.0)
                    Text("Low").tag(0.15)
                    Text("Medium").tag(0.3)
                    Text("High").tag(0.45)
                }
                Toggle("Calm Mode", isOn: $settings.calmMode)
            } footer: {
                Text("Larger text and bold tile borders help low vision. Dimming eases light sensitivity. Calm Mode removes all animation and mutes the tile colours. For a listener who is deaf or hard of hearing, turn on Music Haptics (Setup Checklist) to feel the beat.")
            }
        }
        .navigationTitle("Seeing & Hearing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TouchSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Reduce repeat taps", isOn: $settings.reduceRepeatTaps)
                Toggle("Stronger tap feedback", isOn: $settings.strongHaptics)
            } footer: {
                Text("Reduce repeat taps ignores extra touches for a moment after each tap. Stronger feedback makes accepted taps easier to feel. See the Setup Checklist for iOS Touch Accommodations.")
            }
        }
        .navigationTitle("Touch")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScheduleSettings: View {
    @Bindable var settings: AppSettings
    @Environment(ScheduleService.self) private var schedule

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60,
                    minute: minutes.wrappedValue % 60,
                    second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }

    var body: some View {
        Form {
            Section {
                Toggle("Quiet hours", isOn: $settings.quietHoursEnabled)
                if settings.quietHoursEnabled {
                    DatePicker(
                        "Music sleeps at",
                        selection: timeBinding($settings.quietStartMinutes),
                        displayedComponents: .hourAndMinute)
                    DatePicker(
                        "Music wakes at",
                        selection: timeBinding($settings.quietEndMinutes),
                        displayedComponents: .hourAndMinute)
                }
                Picker("Daily limit", selection: $settings.dailyLimitMinutes) {
                    Text("Off").tag(0)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                    Text("4 hours").tag(240)
                }
            } header: {
                Text("Every day")
            } footer: {
                Text("A spoken and visual warning comes two minutes before music stops, and the stop lands at the end of the song. Today so far: \(schedule.todayMinutes) min. Listening is counted while Boombox is open.")
            }

            Section {
                if let deadline = schedule.sleepDeadline {
                    LabeledContent(
                        "Music stops",
                        value: deadline.formatted(date: .omitted, time: .shortened))
                    Button("Cancel Sleep Timer", role: .destructive) {
                        schedule.cancelSleepTimer()
                    }
                } else {
                    HStack {
                        ForEach([30, 60, 90], id: \.self) { minutes in
                            Button("\(minutes) min") {
                                schedule.armSleepTimer(minutes: minutes)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } header: {
                Text("Sleep Timer")
            } footer: {
                Text("Stops the music once, tonight. Quiet hours handle every night.")
            }
        }
        .navigationTitle("Schedule & Limits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LyricsSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show words on Now Playing", isOn: $settings.showLyrics)
            } footer: {
                Text("Shows big-text lyrics that follow along with the song, in place of the artwork. Words come from a free community lyrics service (LRCLIB), so some songs won't have them — and they aren't Apple's official lyrics.")
            }
        }
        .navigationTitle("Lyrics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ContentSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Allow explicit songs", isOn: $settings.allowExplicit)
            } footer: {
                Text("When off, songs marked explicit are skipped during playback and hidden in the playlist builder. Starting a tile takes slightly longer while filtering. iOS Screen Time can also block explicit music device-wide.")
            }
        }
        .navigationTitle("Content")
        .navigationBarTitleDisplayMode(.inline)
    }
}
