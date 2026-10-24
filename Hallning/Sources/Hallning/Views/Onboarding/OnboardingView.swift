import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var flow: OnboardingFlow?

    var body: some View {
        Group {
            if let flow {
                OnboardingContent(flow: flow)
            } else {
                Color.clear
            }
        }
        .frame(width: 860, height: 640)
        .background(.background)
        .onAppear { if flow == nil { flow = OnboardingFlow(model: model) } }
    }
}

private struct OnboardingContent: View {
    @Bindable var flow: OnboardingFlow
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            switch flow.step {
            case .welcome: WelcomeStep(flow: flow)
            case .permissions: PermissionsStep(flow: flow)
            case .placement: PlacementStep(flow: flow)
            case .good, .bad: CaptureStep(flow: flow)
            case .review: ReviewStep(flow: flow) { dismiss() }
            }
        }
        .id(flow.step)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: flow.step)
        .padding(.top, 28)
    }
}

/// Title, body and a bottom bar shared by the steps.
private struct StepLayout<Content: View, Actions: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.vertical, 20)

            HStack(spacing: 12) { actions }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let flow: OnboardingFlow

    var body: some View {
        StepLayout(title: "Välkommen till Hållning", subtitle: "Din Mac håller ett öga på hur du sitter – och säger till i tid.") {
            HStack(spacing: 48) {
                BreathingFigure()
                    .frame(width: 220, height: 220)
                    .padding(28)
                    .glassEffect(.regular.tint(.teal.opacity(0.15)), in: Circle())
                VStack(alignment: .leading, spacing: 22) {
                    FeatureRow(symbol: "lock.fill", tint: .blue, title: "Allt sker lokalt",
                               detail: "Bilderna analyseras direkt på din Mac med Apples Vision och sparas aldrig.")
                    FeatureRow(symbol: "figure.stand", tint: .teal, title: "Lär sig din kropp",
                               detail: "Du visar 10 bra och 10 dåliga hållningar, så känner appen igen just dig.")
                    FeatureRow(symbol: "capsule.fill", tint: .indigo, title: "Fungerar med Dynamic Island",
                               detail: "Påminnelser och status visas i ön när den är igång – annars som notis.")
                }
                .frame(maxWidth: 360)
            }
        } actions: {
            Spacer()
            Button("Kom igång") { flow.next() }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Permissions

private struct PermissionsStep: View {
    let flow: OnboardingFlow
    @Environment(AppModel.self) private var model

    var body: some View {
        StepLayout(title: "Behörigheter", subtitle: "Hållning behöver kameran. Resten är valfritt.") {
            VStack(spacing: 12) {
                PermissionRow(symbol: "web.camera.fill", tint: .teal, title: "Kamera",
                              detail: "Krävs. En kort bild var 10:e sekund, som aldrig sparas.",
                              state: cameraState) {
                    Task { await flow.requestCamera() }
                }
                PermissionRow(symbol: "bell.badge.fill", tint: .red, title: "Notiser",
                              detail: "För påminnelser när Dynamic Island inte är igång.",
                              state: notificationState) {
                    Task { await flow.requestNotifications() }
                }
                PermissionRow(symbol: "airpods.pro", tint: .blue, title: "AirPods huvudvinkel",
                              detail: airPodsDetail, state: airPodsState) {
                    model.settings.useAirPods = true
                    model.activateAirPods()
                }
            }
            .frame(maxWidth: 560)
        } actions: {
            Button("Tillbaka") { flow.back() }
            Spacer()
            Button("Fortsätt") { flow.next() }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(flow.cameraStatus != .authorized)
                .keyboardShortcut(.defaultAction)
        }
        .task { await flow.refreshPermissions() }
    }

    private var cameraState: PermissionRow.Status {
        switch flow.cameraStatus {
        case .authorized: .granted
        case .denied, .restricted: .denied(settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
        default: .request("Tillåt")
        }
    }

    private var notificationState: PermissionRow.Status {
        switch flow.notificationStatus {
        case .authorized, .provisional: .granted
        case .denied: .denied(settingsURL: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        default: .request("Tillåt")
        }
    }

    private var airPodsState: PermissionRow.Status {
        let motion = model.motion
        if !motion.isAvailable { return .unavailable("Stöds inte") }
        if motion.authorization == .denied || motion.authorization == .restricted {
            return .denied(settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion")
        }
        if motion.isReceiving || (motion.authorization == .authorized && model.settings.useAirPods) { return .granted }
        return .request("Aktivera")
    }

    private var airPodsDetail: String {
        let motion = model.motion
        if motion.isReceiving { return "Ansluten – huvudvinkeln används tillsammans med kameran." }
        if motion.isConnected { return "AirPods anslutna." }
        return "Valfritt. Mäter hur mycket du böjer nacken. Inga AirPods – bara kamera."
    }
}

private struct PermissionRow: View {
    enum Status {
        case granted
        case request(String)
        case denied(settingsURL: String)
        case unavailable(String)
    }

    var symbol: String
    var tint: Color
    var title: String
    var detail: String
    var state: Status
    var action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            FeatureRow(symbol: symbol, tint: tint, title: title, detail: detail)
            Spacer(minLength: 12)
            switch state {
            case .granted:
                Label("Klart", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            case .request(let title):
                Button(title, action: action)
                    .buttonStyle(.glass)
            case .denied(let url):
                Button("Öppna Inställningar") {
                    if let url = URL(string: url) { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.glass)
            case .unavailable(let text):
                Text(text).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Placement

private struct PlacementStep: View {
    let flow: OnboardingFlow
    @Environment(AppModel.self) private var model

    var body: some View {
        let pose = model.livePose
        let shoulders = pose?.hasShoulders == true
        let face = pose?.face != nil || pose?.hasHead == true
        StepLayout(title: "Placering", subtitle: "Sitt som vanligt. Kameran behöver se ditt huvud och båda axlarna.") {
            HStack(spacing: 28) {
                LiveCameraView(cornerRadius: 20)
                    .frame(width: 440, height: 300)
                VStack(alignment: .leading, spacing: 16) {
                    CheckRow(title: "Axlarna syns", isOn: shoulders)
                    CheckRow(title: "Ansiktet syns", isOn: face)
                    Text("Tips: sitt ungefär en armlängd från skärmen med kameran i ögonhöjd, och undvik starkt motljus.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 240)
            }
        } actions: {
            Button("Tillbaka") { flow.back() }
            Spacer()
            Button("Fortsätt") { flow.next() }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(!(shoulders && face))
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct CheckRow: View {
    var title: String
    var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
                .foregroundStyle(isOn ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(.title3.weight(.medium))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isOn)
    }
}

// MARK: - Capture

private struct CaptureStep: View {
    let flow: OnboardingFlow
    @Environment(AppModel.self) private var model

    var body: some View {
        let isGood = flow.step == .good
        let tint: Color = isGood ? .green : .orange
        let done = flow.promptIndex >= flow.prompts.count
        StepLayout(title: isGood ? "10 bra hållningar" : "10 dåliga hållningar",
                   subtitle: isGood ? "Visa hur du sitter när du sitter bra – i olika vardagliga lägen."
                                    : "Överdriv gärna lite. Varje hållning kopplas till ett eget råd.") {
            HStack(spacing: 28) {
                LiveCameraView(cornerRadius: 20)
                    .frame(width: 440, height: 300)
                    .overlay { CaptureOverlay(phase: flow.phase, tint: tint) }
                ZStack { promptCard(tint: tint, done: done) }
                    .frame(width: 280)
                    .clipped()
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: flow.promptIndex)
            }
        } actions: {
            Button("Tillbaka") { flow.back() }
                .disabled(flow.isBusy)
            Button("Gör om") { flow.redo() }
                .disabled(flow.isBusy || flow.capturedInStep == 0)
            Spacer()
            ProgressDots(count: flow.prompts.count, done: flow.capturedInStep, tint: tint)
            Spacer()
            if done {
                Button("Fortsätt") { flow.next() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Ta bild") { flow.capture() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .disabled(flow.isBusy)
                    .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    @ViewBuilder
    private func promptCard(tint: Color, done: Bool) -> some View {
        let prompt = flow.prompt
        VStack(alignment: .leading, spacing: 12) {
            if done {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(tint)
                Text("Alla tio klara").font(.title2.weight(.semibold))
                Text("Bra jobbat. Fortsätt till nästa del.")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(flow.step == .good ? "Bra" : "Dålig") hållning \(flow.promptIndex + 1) av \(flow.prompts.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                HStack(alignment: .bottom, spacing: 10) {
                    PostureFigure(slouch: prompt.slouch)
                        .fill(tint.gradient)
                        .frame(width: 72, height: 72)
                    Image(systemName: prompt.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(prompt.title)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(prompt.instruction)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let issue = prompt.issue {
                    Label("Råd: \(issue.title)", systemImage: "lightbulb.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if case .failed(let message) = flow.phase {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tryck på Ta bild eller mellanslag.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .id(flow.promptIndex)
        .transition(.push(from: .trailing))
    }
}

/// The countdown ring, "Håll stilla" and the checkmark over the camera.
private struct CaptureOverlay: View {
    var phase: OnboardingFlow.Phase
    var tint: Color

    var body: some View {
        ZStack {
            switch phase {
            case .countdown(let second):
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(second) / 3)
                        .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(second)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 120, height: 120)
                .animation(.easeInOut(duration: 0.9), value: second)
            case .capturing:
                Label("Håll stilla", systemImage: "camera.fill")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: Capsule())
            case .captured:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white, tint)
                    .symbolEffect(.bounce, value: phase)
                    .transition(.scale.combined(with: .opacity))
            case .ready, .failed:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: phase)
    }
}

private struct ProgressDots: View {
    var count: Int
    var done: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index < done ? tint : Color.secondary.opacity(0.3))
                    .frame(width: index == done ? 10 : 7, height: index == done ? 10 : 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: done)
    }
}

// MARK: - Review

private struct ReviewStep: View {
    let flow: OnboardingFlow
    let onDone: () -> Void
    @Environment(AppModel.self) private var model

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 10)

    var body: some View {
        StepLayout(title: "Klart!", subtitle: evaluationText) {
            VStack(spacing: 18) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(flow.samples) { sample in
                        PoseThumbnail(pose: sample.pose, color: sample.label == .good ? .green : .orange)
                            .frame(height: 64)
                            .overlay(alignment: .topTrailing) {
                                if model.evaluation?.misses.contains(sample.id) == true {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.yellow)
                                        .padding(3)
                                }
                            }
                    }
                }
                HStack(spacing: 20) {
                    LiveCameraView(cornerRadius: 16)
                        .frame(width: 280, height: 180)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Testa direkt").font(.headline)
                        Text("Sitt bra och sedan dåligt – stämmer det?")
                            .foregroundStyle(.secondary)
                        liveVerdict
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        } actions: {
            Button("Börja om") { flow.restartCaptures() }
            Spacer()
            Button("Klar") {
                model.monitor.start()
                onDone()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .keyboardShortcut(.defaultAction)
            .disabled(!model.isCalibrated)
        }
    }

    private var evaluationText: String {
        if !model.isCalibrated { return "Det behövs minst en bra och en dålig hållning." }
        if model.isEvaluating { return "Räknar ut träffsäkerheten …" }
        guard let evaluation = model.evaluation, evaluation.total > 0 else { return "Hållning har lärt sig hur du sitter." }
        return "Träffsäkerhet: \(evaluation.correct) av \(evaluation.total) poser"
    }

    @ViewBuilder
    private var liveVerdict: some View {
        if let result = model.liveResult {
            let threshold = model.settings.sensitivity.threshold
            let isBad = result.badProbability >= threshold
            HStack(spacing: 10) {
                FigureRing(progress: 1 - result.badProbability, slouch: isBad ? 0.85 : 0,
                           color: result.isUncertain ? .yellow : (isBad ? .orange : .green), lineWidth: 4, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.isUncertain ? "Osäker" : (isBad ? (result.issue ?? .slouching).title : "Bra hållning"))
                        .font(.title3.weight(.semibold))
                    Text("Sannolikhet för dålig hållning: \(percent(result.badProbability))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isBad)
        } else {
            Label("Ser ingen", systemImage: "person.fill.questionmark")
                .foregroundStyle(.secondary)
        }
    }
}
