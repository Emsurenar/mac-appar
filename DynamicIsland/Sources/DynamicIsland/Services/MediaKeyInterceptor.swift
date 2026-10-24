import AppKit
import ApplicationServices

/// Intercepts the volume and brightness keys so the island can replace the
/// system HUD. Requires the Accessibility permission.
@MainActor
final class MediaKeyInterceptor {
    enum Key {
        case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    }

    /// Return true to consume the key (and suppress the system HUD).
    var handler: ((Key, _ fine: Bool) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var consumedKeys = Set<Int>()

    var isRunning: Bool { tap != nil }

    static var hasPermission: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasPermission else { return false }
        let systemDefined = CGEventMask(1 << 14) // NX_SYSDEFINED
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: systemDefined,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { interceptor.handle(type: type, event: event) }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let code = (nsEvent.data1 & 0xFFFF_0000) >> 16
        let isKeyDown = ((nsEvent.data1 & 0xFF00) >> 8) == 0x0A
        let key: Key
        switch code {
        case 0: key = .volumeUp
        case 1: key = .volumeDown
        case 7: key = .mute
        case 2: key = .brightnessUp
        case 3: key = .brightnessDown
        default: return Unmanaged.passUnretained(event)
        }

        let fine = nsEvent.modifierFlags.contains([.option, .shift])
        if isKeyDown {
            let consumed = handler?(key, fine) == true
            if consumed { consumedKeys.insert(code) } else { consumedKeys.remove(code) }
            return consumed ? nil : Unmanaged.passUnretained(event)
        }
        // Key-up follows whatever happened to its key-down.
        return consumedKeys.remove(code) != nil ? nil : Unmanaged.passUnretained(event)
    }
}
