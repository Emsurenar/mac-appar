import CoreGraphics
import Foundation

/// Built-in display brightness through the private DisplayServices framework
/// (the same one the brightness keys and Control Center use).
@MainActor @Observable
final class BrightnessService {
    private(set) var brightness: Double = 0
    private(set) var isAvailable = false

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    @ObservationIgnored private var getter: GetBrightness?
    @ObservationIgnored private var setter: SetBrightness?
    @ObservationIgnored private let display: CGDirectDisplayID

    init() {
        display = Self.builtInDisplay() ?? CGMainDisplayID()
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
           let get = dlsym(handle, "DisplayServicesGetBrightness"),
           let set = dlsym(handle, "DisplayServicesSetBrightness") {
            getter = unsafeBitCast(get, to: GetBrightness.self)
            setter = unsafeBitCast(set, to: SetBrightness.self)
        }
        refresh()
    }

    func refresh() {
        guard let getter else { return }
        var value: Float = 0
        isAvailable = getter(display, &value) == 0
        if isAvailable { brightness = Double(value) }
    }

    func setBrightness(_ value: Double) {
        let value = min(max(value, 0), 1)
        guard let setter, setter(display, Float(value)) == 0 else { return }
        brightness = value
    }

    func step(by steps: Int, fine: Bool) {
        refresh()
        let divisions = fine ? 64.0 : 16.0
        setBrightness(((brightness * divisions).rounded() + Double(steps)) / divisions)
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &displays, &count)
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }
}
