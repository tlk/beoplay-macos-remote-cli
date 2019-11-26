import Foundation

class ConsoleDeviceLocator : NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private var devices = [NetService]()

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove device: NetService, moreComing: Bool) {
        print("- \(device.name)")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind device: NetService, moreComing: Bool) {
        // need to keep a reference to the device object for it to be resolved
        self.devices.append(device)
        device.delegate = self
        device.resolve(withTimeout: 5.0)
    }

    func netServiceDidResolveAddress(_ device: NetService) {
        print("+ \"\(device.name)\"\thttp://\(device.hostName!):\(device.port)")
    }
}
