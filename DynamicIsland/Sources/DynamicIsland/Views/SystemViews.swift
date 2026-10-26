import SwiftUI

extension SystemService {
    /// Memory, CPU, heat and uptime, plus battery and charger when there are any.
    var rowCount: Int {
        4 + (power == nil ? 0 : 1) + (power?.isOnAdapter == true ? 1 : 0)
    }
}

struct SystemTab: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let system = model.system
        VStack(spacing: 0) {
            memoryRow
            cpuRow
            SystemRow(symbol: "thermometer.medium", title: "Heat", detail: thermalDetail,
                      value: thermalValue.text, level: thermalValue.level)
            if let power = system.power {
                batteryRow(power)
                if power.isOnAdapter { chargerRow(power) }
            }
            uptimeRow
        }
        .padding(.horizontal, -6)
        .padding(.top, 4)
        .onAppear { system.start() }
        .onDisappear { system.stop() }
    }

    // MARK: Rows

    private var memoryRow: some View {
        let system = model.system
        let top = system.topMemory
        var detail = top.map { "\($0.name) uses \(formatBytes($0.value))" } ?? ""
        if system.swapUsed > 0 { detail += (detail.isEmpty ? "" : " · ") + "\(formatBytes(Double(system.swapUsed))) swap" }
        let value = switch system.memoryPressure {
        case .normal: "Normal"
        case .warning: "High"
        case .critical: "Full"
        }
        return SystemRow(symbol: "memorychip", title: "Memory", detail: detail, value: value,
                         level: system.memoryPressure,
                         action: system.memoryPressure > .normal ? top.flatMap(quitAction) : nil)
    }

    private var cpuRow: some View {
        let system = model.system
        let top = system.topCPU
        let isStuck = system.busySeconds >= 60
        var detail = top.map { "\($0.name) is busiest" } ?? "Measuring…"
        if isStuck { detail = "\(top?.name ?? "") busy for \(formatDuration(system.busySeconds))" }
        return SystemRow(symbol: "cpu", title: "CPU", detail: detail,
                         value: top.map { "\(Int($0.value.rounded())) %" } ?? "–",
                         level: isStuck ? .warning : .normal,
                         action: isStuck ? top.flatMap(quitAction) : nil)
    }

    private var thermalValue: (text: String, level: SystemService.Level) {
        switch model.system.thermalState {
        case .nominal: ("Cool", .normal)
        case .fair: ("Warm", .normal)
        case .serious: ("Throttling", .warning)
        case .critical: ("Throttling hard", .critical)
        @unknown default: ("–", .normal)
        }
    }

    private var thermalDetail: String {
        switch model.system.thermalState {
        case .serious, .critical: "Slowed down to cool off. Close heavy apps."
        default: "Running at full speed"
        }
    }

    private func batteryRow(_ power: SystemService.Power) -> some View {
        let watts = abs(power.watts)
        let isDraining = power.watts < -0.5
        var detail = "\(power.percent) %"
        if let minutes = power.minutesRemaining {
            detail += " · " + formatDuration(TimeInterval(minutes * 60)) + (isDraining ? " left" : " to full")
        }
        let value = isDraining ? String(format: "−%.1f W", watts)
            : power.isCharging ? String(format: "+%.1f W", watts) : "Idle"
        let isHeavy = isDraining && watts >= 20
        if isHeavy { detail += " · heavy draw" }
        return SystemRow(symbol: batterySymbol(power), title: "Battery", detail: detail, value: value,
                         level: isHeavy ? .warning : .normal)
    }

    private func chargerRow(_ power: SystemService.Power) -> some View {
        let notKeepingUp = power.watts < -0.5
        let isWeak = (power.adapterWatts ?? 0) > 0 && (power.adapterWatts ?? 0) < 30
        let detail = notKeepingUp ? "Can't keep up, the battery is draining"
            : isWeak ? "Slow charger. Use a stronger adapter or cable."
            : power.isCharging ? "Charging" : "Connected"
        return SystemRow(symbol: "powerplug.fill", title: "Charger", detail: detail,
                         value: power.adapterWatts.map { "\($0) W" } ?? "–",
                         level: notKeepingUp || isWeak ? .warning : .normal)
    }

    private var uptimeRow: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let uptime = model.system.bootDate.map { context.date.timeIntervalSince($0) } ?? 0
            let isLong = uptime >= 14 * 86_400
            SystemRow(symbol: "clock.arrow.circlepath", title: "Uptime",
                      detail: isLong ? "A restart clears out slowdowns" : "Since the last restart",
                      value: formatDuration(uptime), level: isLong ? .warning : .normal)
        }
    }

    // MARK: Helpers

    private func quitAction(_ usage: SystemService.Usage) -> SystemRow.Action? {
        guard usage.appURL != nil else { return nil }
        return SystemRow.Action(title: "Quit") { model.system.quit(usage) }
    }

    private func batterySymbol(_ power: SystemService.Power) -> String {
        if power.isCharging { return "battery.100percent.bolt" }
        return switch power.percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

private struct SystemRow: View {
    struct Action {
        let title: String
        let perform: () -> Void
    }

    var symbol: String
    var title: String
    var detail: String
    var value: String
    var level: SystemService.Level
    var action: Action?

    private var tint: Color {
        switch level {
        case .normal: .white
        case .warning: .orange
        case .critical: .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(level == .normal ? .white : .black)
                .frame(width: 26, height: 26)
                .background(Circle().fill(level == .normal ? Color.white.opacity(0.14) : tint))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if let action {
                Button(action.title, action: action.perform)
                    .buttonStyle(QuitButtonStyle())
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(level == .normal ? .white.opacity(0.75) : tint)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 6)
        .frame(height: IslandLayout.systemRowHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: level)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value)
    }
}

private struct QuitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.28 : 0.16)))
            .contentShape(Capsule())
    }
}

private func formatBytes(_ bytes: Double) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let hours = minutes / 60
    let days = hours / 24
    if days > 0 { return "\(days) d \(hours % 24) h" }
    if hours > 0 { return "\(hours) h \(minutes % 60) min" }
    if minutes > 0 { return "\(minutes) min" }
    return "\(Int(seconds)) s"
}
