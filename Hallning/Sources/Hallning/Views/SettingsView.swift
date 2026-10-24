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
                Picker("Kontrollera", selection: $settings.interval) {
                    Text("Var 5:e sekund").tag(5.0)
                    Text("Var 10:e sekund").tag(10.0)
                    Text("Var 20:e sekund").tag(20.0)
                    Text("Var 30:e sekund").tag(30.0)
                    Text("Varje minut").tag(60.0)
                }
            } header: {
                Text("Kontroller")
            } footer: {
                Text("Kameran är på hela tiden medan Hållning bevakar, så lampan blinkar inte. Den stängs av när du pausar, låser skärmen eller är i ett videosamtal.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Påminn efter") {
                    Stepper(value: $settings.alertMinutes, in: 1...10, step: 1) {
                        Text("\(Int(settings.alertMinutes)) min")
                            .monospacedDigit()
                    }
                }
                LabeledContent("Andel dålig hållning") {
                    HStack {
                        Slider(value: $settings.alertThreshold, in: 0.6...1, step: 0.05)
                            .frame(width: 160)
                        Text(percent(settings.alertThreshold))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Picker("Känslighet", selection: $settings.sensitivity) {
                    ForEach(Sensitivity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Visa påminnelser i", selection: $settings.alertStyle) {
                    ForEach(AlertStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Spela ett mjukt ljud i Dynamic Island", isOn: $settings.playSound)
                    .disabled(settings.alertStyle != .islandFirst)
            } header: {
                Text("Påminnelser")
            } footer: {
                Text("Du får en påminnelse när minst \(percent(settings.alertThreshold)) av kontrollerna under \(Int(settings.alertMinutes)) min visar dålig hållning.")
                    .foregroundStyle(.secondary)
            }

            Section("Kamera") {
                Picker("Kamera", selection: $settings.cameraID) {
                    Text("Automatisk").tag(String?.none)
                    ForEach(cameras) { Text($0.name).tag(Optional($0.id)) }
                }
                Toggle("Pausa under videosamtal", isOn: $settings.pauseDuringCalls)
            }

            Section {
                Toggle("Använd huvudvinkeln från AirPods", isOn: $settings.useAirPods)
                LabeledContent("Status", value: airPodsStatus)
                if let angle = model.neckAngle {
                    NeckGauge(angle: angle, limit: settings.maxNeckAngle)
                        .padding(.vertical, 4)
                }
                Group {
                    LabeledContent("Högsta nackvinkel") {
                        Stepper(value: $settings.maxNeckAngle, in: 5...35, step: 1) {
                            Text("\(Int(settings.maxNeckAngle))° ned")
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("Påminn efter") {
                        Stepper(value: $settings.neckAlertMinutes, in: 1...10, step: 1) {
                            Text("\(Int(settings.neckAlertMinutes)) min")
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("Neutralläge") {
                        HStack(spacing: 8) {
                            Text(settings.neckNeutralPitch == nil ? "Automatiskt" : "Inställt")
                                .foregroundStyle(.secondary)
                            if settings.neckNeutralPitch != nil {
                                Button("Återställ") { model.resetNeckNeutral() }
                            }
                            Button("Ställ in nu") { model.setNeckNeutral() }
                                .disabled(!model.motion.isReceiving)
                        }
                    }
                }
                .disabled(!settings.useAirPods)
            } header: {
                Text("AirPods")
            } footer: {
                Text("Du får en påminnelse när nacken har varit böjd mer än \(Int(settings.maxNeckAngle))° i \(Int(settings.neckAlertMinutes)) min. Sitt rakt och titta på skärmen när du ställer in neutralläget – vinkeln räknas därifrån. Fungerar med AirPods Pro, AirPods Max och AirPods (3:e generationen och senare).")
                    .foregroundStyle(.secondary)
            }

            Section("Dynamic Island") {
                LabeledContent("Anslutning") {
                    Label(model.island.isIslandActive ? "Ansluten" : "Inte igång",
                          systemImage: model.island.isIslandActive ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(model.island.isIslandActive ? Color.green : Color.secondary)
                }
            }

            Section("Allmänt") {
                Toggle("Starta vid inloggning", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section {
                Button("Radera all data…", role: .destructive) { confirmDelete = true }
            } header: {
                Text("Integritet")
            } footer: {
                Text("Allt sker lokalt på din Mac. Bilder sparas aldrig – bara ledpunkternas koordinater och statistik per minut.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Inställningar")
        .onAppear { cameras = CameraService.availableDevices() }
        .confirmationDialog("Radera all data?", isPresented: $confirmDelete) {
            Button("Radera kalibrering och historik", role: .destructive) { model.deleteAllData() }
        } message: {
            Text("Kalibreringen och all statistik tas bort. Du får kalibrera igen.")
        }
    }

    private var airPodsStatus: String {
        let motion = model.motion
        if !model.settings.useAirPods { return "Av" }
        if !motion.isAvailable { return "Stöds inte" }
        if motion.authorization == .denied || motion.authorization == .restricted { return "Ingen behörighet" }
        if motion.isReceiving { return "Tar emot huvudvinkel" }
        if motion.isConnected { return "Anslutna" }
        return "Inga AirPods – bara kamera"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
