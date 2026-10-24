import ServiceManagement
import SwiftUI

// The settings panes of the main window, laid out like System Settings.

struct RemindersPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                PaneHeader(title: "Reminders") {
                    SettingsIcon(MainSection.reminders.symbol, color: MainSection.reminders.color, size: 40)
                } detail: {
                    Text("Choose how often Posture checks how you sit, and when it reminds you.")
                }
            }

            Section {
                Picker("Check posture", selection: $settings.interval) {
                    Text("Every 5 seconds").tag(5.0)
                    Text("Every 10 seconds").tag(10.0)
                    Text("Every 20 seconds").tag(20.0)
                    Text("Every 30 seconds").tag(30.0)
                    Text("Every minute").tag(60.0)
                }
                LabeledContent("Remind after") {
                    Stepper(value: $settings.alertMinutes, in: 1...10, step: 1) {
                        Text("\(Int(settings.alertMinutes)) min")
                            .monospacedDigit()
                    }
                }
                LabeledContent("Share of poor posture") {
                    HStack(spacing: 10) {
                        Slider(value: $settings.alertThreshold, in: 0.6...1, step: 0.05)
                            .frame(width: 160)
                        Text(percent(settings.alertThreshold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                Picker("Sensitivity", selection: $settings.sensitivity) {
                    ForEach(Sensitivity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("You get a reminder when at least \(percent(settings.alertThreshold)) of the checks over \(Int(settings.alertMinutes)) min show poor posture. A higher sensitivity counts borderline postures as poor.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Show reminders in", selection: $settings.alertStyle) {
                    ForEach(AlertStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Play a sound in Dynamic Island", isOn: $settings.playSound)
                    .disabled(settings.alertStyle != .islandFirst)
            } footer: {
                Text("Notifications are used when Dynamic Island isn't running.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AirPodsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                PaneHeader(title: "AirPods") {
                    SettingsIcon(MainSection.airPods.symbol, color: MainSection.airPods.color, size: 40)
                } detail: {
                    Text("Use the head angle from AirPods Pro, AirPods Max or AirPods (3rd generation and later) to notice when your neck bends.")
                } trailing: {
                    Toggle("Use AirPods", isOn: $settings.useAirPods)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Section {
                LabeledContent("Status", value: airPodsStatus)
                if let angle = model.neckAngle {
                    NeckGauge(angle: angle, limit: settings.maxNeckAngle)
                        .padding(.vertical, 4)
                }
            }

            Section {
                LabeledContent("Maximum neck angle") {
                    Stepper(value: $settings.maxNeckAngle, in: 5...35, step: 1) {
                        Text("\(Int(settings.maxNeckAngle))° down")
                            .monospacedDigit()
                    }
                }
                LabeledContent("Remind after") {
                    Stepper(value: $settings.neckAlertMinutes, in: 1...10, step: 1) {
                        Text("\(Int(settings.neckAlertMinutes)) min")
                            .monospacedDigit()
                    }
                }
                LabeledContent("Neutral position") {
                    HStack(spacing: 8) {
                        Text(settings.neckNeutralPitch == nil ? "Automatic" : "Set")
                            .foregroundStyle(.secondary)
                        if settings.neckNeutralPitch != nil {
                            Button("Reset") { model.resetNeckNeutral() }
                        }
                        Button("Set Now") { model.setNeckNeutral() }
                            .disabled(!model.motion.isReceiving)
                    }
                }
            } header: {
                Text("Neck")
            } footer: {
                Text("You get a reminder when your neck has been bent more than \(Int(settings.maxNeckAngle))° for \(Int(settings.neckAlertMinutes)) min. To set the neutral position, sit up straight, look at the screen and click Set Now.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.useAirPods)
        }
        .formStyle(.grouped)
    }

    private var airPodsStatus: String {
        let motion = model.motion
        if !model.settings.useAirPods { return "Off" }
        if !motion.isAvailable { return "Not supported" }
        if motion.authorization == .denied || motion.authorization == .restricted { return "No permission" }
        if motion.isReceiving { return "Receiving head angle" }
        if motion.isConnected { return "Connected" }
        return "Not connected"
    }
}

struct CameraPane: View {
    @Environment(AppModel.self) private var model
    @State private var cameras: [CameraDevice] = []

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                PaneHeader(title: "Camera") {
                    SettingsIcon(MainSection.camera.symbol, color: MainSection.camera.color, size: 40)
                } detail: {
                    Text("Posture keeps the camera on while it watches, so its light stays steady. Images are analysed on your Mac and never saved.")
                }
            }

            Section {
                Picker("Camera", selection: $settings.cameraID) {
                    Text("Automatic").tag(String?.none)
                    ForEach(cameras) { Text($0.name).tag(Optional($0.id)) }
                }
                Toggle("Pause during video calls", isOn: $settings.pauseDuringCalls)
            } footer: {
                Text("The camera turns off while Posture is paused, when the screen is locked and during video calls.")
                    .foregroundStyle(.secondary)
            }

            Section("Preview") {
                Toggle("Show live preview", isOn: $settings.showLiveCamera)
                if settings.showLiveCamera {
                    LiveCameraView(cornerRadius: 8)
                        .frame(height: 300)
                        .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { cameras = CameraService.availableDevices() }
    }
}

struct GeneralPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                PaneHeader(title: "General") {
                    SettingsIcon(MainSection.general.symbol, color: MainSection.general.color, size: 40)
                } detail: {
                    Text("Posture \(version) · Everything happens on your Mac.")
                }
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                LabeledContent("Dynamic Island") {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.island.isIslandActive ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(model.island.isIslandActive ? "Connected" : "Not running")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent {
                    Button("Delete All Data…", role: .destructive) { confirmDelete = true }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calibration and history")
                        Text("Images are never saved – only joint coordinates and per-minute statistics.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete all data?", isPresented: $confirmDelete) {
            Button("Delete Calibration and History", role: .destructive) { model.deleteAllData() }
        } message: {
            Text("The calibration and all statistics are removed. You will need to calibrate again.")
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
