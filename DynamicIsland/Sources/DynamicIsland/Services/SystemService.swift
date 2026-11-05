import AppKit
import Darwin
import IOKit

/// Readings for the System tab, picked because each one suggests something to do:
/// memory and CPU hogs, throttling, battery drain, a weak charger and a long uptime.
/// Polls only while the tab is visible.
@MainActor @Observable
final class SystemService {
    enum Level: Int, Comparable {
        case normal, warning, critical
        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// An app (all of its helper processes together) or a lone process.
    struct Usage: Equatable {
        let name: String
        let value: Double
        /// The bundle when the usage belongs to an app, so it can be quit.
        let appURL: URL?

        /// Running apps other than this one can be asked to quit.
        var isQuittable: Bool {
            guard let path = appURL?.standardizedFileURL.path,
                  path != Bundle.main.bundleURL.standardizedFileURL.path else { return false }
            return NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.standardizedFileURL.path == path }
        }
    }

    struct Power: Equatable {
        var percent: Int
        var isOnAdapter: Bool
        var isCharging: Bool
        /// Positive while charging, negative while draining.
        var watts: Double
        var minutesRemaining: Int?
        var adapterWatts: Int?
    }

    private(set) var memoryPressure: Level = .normal
    private(set) var swapUsed: UInt64 = 0
    /// Physical footprint in bytes.
    private(set) var topMemory: Usage?
    /// Percent of one core.
    private(set) var topCPU: Usage?
    /// How long the busiest app has stayed above `busyThreshold`.
    private(set) var busySeconds: TimeInterval = 0
    /// Apps using the most CPU, which is what drains the battery. Shown when the battery row is open.
    private(set) var energyHogs: [Usage] = []
    /// Whether the battery row is open to list `energyHogs`.
    var showsEnergy = false
    static let maxEnergyRows = 5
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var power: Power?
    let bootDate: Date?

    static let busyThreshold = 80.0
    private static let interval: TimeInterval = 2

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastCPUTimes: [pid_t: UInt64] = [:]
    @ObservationIgnored private var lastSampleTime: UInt64 = 0
    @ObservationIgnored private var groupKeys: [pid_t: String] = [:]

    init() {
        bootDate = Self.sysctl("kern.boottime", timeval()).map { Date(timeIntervalSince1970: TimeInterval($0.tv_sec)) }
        power = Self.readPower()
        thermalState = ProcessInfo.processInfo.thermalState
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        // A later sample would span the hidden time and blur the CPU numbers.
        lastSampleTime = 0
        lastCPUTimes = [:]
        busySeconds = 0
        energyHogs = []
        showsEnergy = false
    }

    func refresh() {
        memoryPressure = switch Self.sysctl("kern.memorystatus_vm_pressure_level", Int32(0)) {
        case 4: .critical
        case 2: .warning
        default: .normal
        }
        swapUsed = Self.sysctl("vm.swapusage", xsw_usage())?.xsu_used ?? 0
        thermalState = ProcessInfo.processInfo.thermalState
        power = Self.readPower()
        sampleProcesses()
    }

    /// Asks the app to quit, the same as choosing Quit from its menu.
    func quit(_ usage: Usage) {
        guard usage.isQuittable, let path = usage.appURL?.standardizedFileURL.path else { return }
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL?.standardizedFileURL.path == path }
            .forEach { $0.terminate() }
    }

    // MARK: Processes

    private func sampleProcesses() {
        let now = mach_absolute_time()
        let elapsed = lastSampleTime > 0 ? Double(now - lastSampleTime) : 0

        var pids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))

        var memory: [String: UInt64] = [:]
        var cpu: [String: Double] = [:]
        var times: [pid_t: UInt64] = [:]
        var keys: [pid_t: String] = [:]

        for pid in pids.prefix(max(count, 0)) where pid > 0 {
            var info = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            }
            guard result == 0, let key = groupKeys[pid] ?? Self.groupKey(for: pid) else { continue }
            keys[pid] = key
            memory[key, default: 0] += info.ri_phys_footprint

            // CPU times and mach_absolute_time share a unit, so their ratio is the share of one core.
            let time = info.ri_user_time + info.ri_system_time
            times[pid] = time
            if elapsed > 0, let previous = lastCPUTimes[pid], time >= previous {
                cpu[key, default: 0] += Double(time - previous) / elapsed * 100
            }
        }

        lastSampleTime = now
        lastCPUTimes = times
        groupKeys = keys

        topMemory = memory.max { $0.value < $1.value }.map { Self.usage(key: $0.key, value: Double($0.value)) }
        let busiest = cpu.max { $0.value < $1.value }.map { Self.usage(key: $0.key, value: $0.value) }
        if let busiest, busiest.value >= Self.busyThreshold {
            busySeconds = busiest.name == topCPU?.name ? busySeconds + Self.interval : Self.interval
        } else {
            busySeconds = 0
        }
        topCPU = busiest
        if elapsed > 0 {
            energyHogs = cpu.filter { $0.key.hasSuffix(".app") && $0.value >= 0.5 }
                .sorted { $0.value > $1.value }
                .prefix(Self.maxEnergyRows)
                .map { Self.usage(key: $0.key, value: $0.value) }
        }
    }

    /// The enclosing app bundle for a process, so helpers count towards their app. Processes
    /// that macOS launches for an app, such as Safari's web pages, count towards that app too.
    private static func groupKey(for pid: pid_t) -> String? {
        let responsible = responsiblePID(pid)
        if responsible > 0, responsible != pid, let key = bundleKey(for: responsible), key.hasSuffix(".app") {
            return key
        }
        return bundleKey(for: pid)
    }

    private static func bundleKey(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(cString: buffer)
        guard let range = path.range(of: ".app/") else { return path }
        return String(path[..<range.lowerBound]) + ".app"
    }

    private static func responsiblePID(_ pid: pid_t) -> pid_t {
        typealias Function = @convention(c) (pid_t) -> pid_t
        guard let symbol = responsibilitySymbol else { return -1 }
        return unsafeBitCast(symbol, to: Function.self)(pid)
    }

    /// The same lookup Activity Monitor uses. Looked up at runtime because it isn't in the SDK headers.
    private static let responsibilitySymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")

    private static func usage(key: String, value: Double) -> Usage {
        let isApp = key.hasSuffix(".app")
        let name = isApp ? FileManager.default.displayName(atPath: key) : (key as NSString).lastPathComponent
        return Usage(name: name.replacingOccurrences(of: ".app", with: ""), value: value,
                     appURL: isApp ? URL(fileURLWithPath: key) : nil)
    }

    // MARK: Power

    private static func readPower() -> Power? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let battery = properties?.takeRetainedValue() as? [String: Any],
              battery["BatteryInstalled"] as? Bool ?? true else { return nil }

        let voltage = battery["Voltage"] as? Int ?? 0 // mV
        // mA, negative when draining. IOKit can hand the negative value over as a large unsigned number.
        let amperage = signedInt(battery["InstantAmperage"]) ?? signedInt(battery["Amperage"]) ?? 0
        let current = battery["CurrentCapacity"] as? Int ?? 0
        let max = battery["MaxCapacity"] as? Int ?? 100
        let isOnAdapter = battery["ExternalConnected"] as? Bool ?? false
        // 65535 means the estimate isn't ready yet.
        let minutes = (battery["TimeRemaining"] as? Int).flatMap { $0 > 0 && $0 < 65535 ? $0 : nil }
        let adapter = battery["AdapterDetails"] as? [String: Any]

        return Power(
            percent: max > 0 ? current * 100 / max : current,
            isOnAdapter: isOnAdapter,
            isCharging: battery["IsCharging"] as? Bool ?? false,
            watts: Double(voltage) * Double(amperage) / 1_000_000,
            minutesRemaining: minutes,
            adapterWatts: isOnAdapter ? (adapter?["Watts"] as? Int).flatMap { $0 > 0 ? $0 : nil } : nil
        )
    }

    private static func signedInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        return Int(truncatingIfNeeded: number.int64Value)
    }

    private static func sysctl<T>(_ name: String, _ initial: T) -> T? {
        var value = initial
        var size = MemoryLayout<T>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
}
