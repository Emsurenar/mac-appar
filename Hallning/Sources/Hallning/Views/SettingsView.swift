import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var cameras: [CameraDevice] = []
    @State private var confirmDelete = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Picker("Check", selection: $settings.interval) {
                    Text("Every 5 seconds").tag(5.0)
                    Text("Every 10 seconds").tag(10.0)
                    Text("Every 20 seconds").tag(20.0)
                    Text("Every 30 seconds").tag(30.0)
                    Text("Every minute").tag(60.0)
                }
            } header: {
                Text("Checks")
            } footer: {
                Text("The camera stays on while Posture is watching, so its light doesn't blink. It turns off when you pause, lock the screen or join a video call.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Remind after") {
                    Stepper(value: $settings.alertMinutes, in: 1...10, step: 1) {
                        Text("\(Int(settings.alertMinutes)) min")
                            .monospacedDigit()
                    }
                }
                LabeledContent("Share of poor posture") {
                    HStack {
                        Slider(value: $settings.alertThreshold, in: 0.6...1, step: 0.05)
                            .frame(width: 160)
                        Text(percent(settings.alertThreshold))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Picker("Sensitivity", selection: $settings.sensitivity) {
                    ForEach(Sensitivity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Show reminders in", selection: $settings.alertStyle) {
                    ForEach(AlertStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Play a soft sound in Dynamic Island", isOn: $settings.playSound)
                    .disabled(settings.alertStyle != .islandFirst)
            } header: {
                Text("Reminders")
            } footer: {
                Text("You get a reminder when at least \(percent(settings.alertThreshold)) of the checks over \(Int(settings.alertMinutes)) min show poor posture.")
                    .foregroundStyle(.secondary)
            }

            Section("Camera") {
                Picker("Camera", selection: $settings.cameraID) {
                    Text("Automatic").tag(String?.none)
                    ForEach(cameras) { Text($0.name).tag(Optional($0.id)) }
                }
                Toggle("Pause during video calls", isOn: $settings.pauseDuringCalls)
            }

            Section {
                Toggle("Use head angle from AirPods", isOn: $settings.useAirPods)
                LabeledContent("Status", value: airPodsStatus)
                if let angle = model.neckAngle {
                    NeckGauge(angle: angle, limit: settings.maxNeckAngle)
                        .padding(.vertical, 4)
                }
                Group {
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
                            Button("Set now") { model.setNeckNeutral() }
                                .disabled(!model.motion.isReceiving)
                        }
                    }
                }
                .disabled(!settings.useAirPods)
            } header: {
                Text("AirPods")
            } footer: {
                Text("You get a reminder when your neck has been bent more than \(Int(settings.maxNeckAngle))° for \(Int(settings.neckAlertMinutes)) min. Sit up straight and look at the screen when you set the neutral position – the angle is measured from there. Works with AirPods Pro, AirPods Max and AirPods (3rd generation and later).")
                    .foregroundStyle(.secondary)
            }

            Section("Dynamic Island") {
                LabeledContent("Connection") {
                    Label(model.island.isIslandActive ? "Connected" : "Not running",
                          systemImage: model.island.isIslandActive ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(model.island.isIslandActive ? Color.green : Color.secondary)
                }
            }

            Section("General") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section {
                Button("Delete all data…", role: .destructive) { confirmDelete = true }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Everything happens locally on your Mac. Images are never saved – only joint coordinates and per-minute statistics.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear { cameras = CameraService.availableDevices() }
        .confirmationDialog("Delete all data?", isPresented: $confirmDelete) {
            Button("Delete calibration and history", role: .destructive) { model.deleteAllData() }
        } message: {
            Text("The calibration and all statistics are removed. You will need to calibrate again.")
        }
    }

    private var airPodsStatus: String {
        let motion = model.motion
        if !model.settings.useAirPods { return "Off" }
        if !motion.isAvailable { return "Not supported" }
        if motion.authorization == .denied || motion.authorization == .restricted { return "No permission" }
        if motion.isReceiving { return "Receiving head angle" }
        if motion.isConnected { return "Connected" }
        return "No AirPods – camera only"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
