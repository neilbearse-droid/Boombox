import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var allSettings: [AppSettings]

    var body: some View {
        if let settings = allSettings.first {
            SettingsForm(settings: settings)
        } else {
            // AppSettings is created at launch; this should never appear.
            ProgressView()
        }
    }
}

private struct SettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(ScheduleService.self) private var schedule
    @State private var showChangePIN = false

    /// Bridges a minutes-of-day Int to a DatePicker.
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60,
                    minute: minutes.wrappedValue % 60,
                    second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents(
                    [.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }

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
            } header: {
                Text("Music Wall")
            } footer: {
                Text("Fewer tiles can help on overwhelming days. Tiles keep their wall order.")
            }

            Section {
                Toggle("Spoken confirmations", isOn: $settings.speakOnPlay)
                Toggle("Calm Mode", isOn: $settings.calmMode)
            } footer: {
                Text("Calm Mode removes all animation and mutes the tile colours.")
            }

            Section("Now Playing") {
                Toggle("Next Song button", isOn: $settings.showNextButton)
            }

            Section {
                Toggle("Allow explicit songs", isOn: $settings.allowExplicit)
            } header: {
                Text("Content")
            } footer: {
                Text("When off, songs marked explicit are skipped during playback and hidden in the playlist builder. Starting a tile takes slightly longer while filtering. iOS Screen Time can also block explicit music device-wide.")
            }

            Section {
                Toggle("Reduce repeat taps", isOn: $settings.reduceRepeatTaps)
                Toggle("Stronger tap feedback", isOn: $settings.strongHaptics)
            } header: {
                Text("Touch")
            } footer: {
                Text("Reduce repeat taps ignores extra touches for a moment after each tap. Stronger feedback makes accepted taps easier to feel.")
            }

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
                Text("Schedule")
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

            Section("Parent PIN") {
                Button("Change PIN") {
                    showChangePIN = true
                }
            }

            Section("Setup") {
                NavigationLink("Setup Checklist") {
                    SetupChecklistView()
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
    }
}
