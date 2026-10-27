import CoreBluetooth
import Foundation
import IOBluetooth

/// Battery for AirPods and Beats, through the private `IOBluetoothDevice` properties
/// that Control Center's AirPods module uses.
@MainActor @Observable
final class AirPodsService {
    /// The emptier earbud's charge in percent. Nil when the output reports no battery.
    private(set) var battery: Int?

    func refresh(for output: AudioOutputDevice?) {
        // Asking IOBluetooth before Bluetooth access is settled shows the prompt, so only
        // do it for a Bluetooth output, which is when the user is looking at the outputs.
        guard let address = output?.bluetoothAddress,
              CBManager.authorization != .denied, CBManager.authorization != .restricted,
              let device = IOBluetoothDevice(addressString: address), device.isConnected() else {
            return update(battery: nil)
        }
        let buds = ["batteryPercentLeft", "batteryPercentRight", "batteryPercentSingle"]
            .compactMap { device.byte($0) }.filter { $0 > 0 }
        update(battery: buds.min().map(Int.init))
    }

    #if DEBUG
    func showPreview() {
        update(battery: 80)
    }
    #endif

    /// Assigns only on a change, so refreshing doesn't redraw the island.
    private func update(battery: Int?) {
        if battery != self.battery { self.battery = battery }
    }
}

private extension IOBluetoothDevice {
    func byte(_ name: String) -> UInt8? {
        typealias Getter = @convention(c) (AnyObject, Selector) -> UInt8
        let selector = NSSelectorFromString(name)
        guard responds(to: selector) else { return nil }
        return unsafeBitCast(method(for: selector), to: Getter.self)(self, selector)
    }
}
