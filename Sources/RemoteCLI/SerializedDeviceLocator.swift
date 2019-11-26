import Foundation

class SerializedDeviceLocator : NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let queue = DispatchQueue(label: "beoplay-single-device-locator")
    private var devices = [NetService]()
    private var isStopped = false

    private var didFind: (NetService) -> ()
    private var didStop: () -> ()

    public init(didFind: @escaping (NetService) -> (), didStop: @escaping () -> ()) {
        self.didFind = didFind
        self.didStop = didStop
    }

    private func stop() {
        self.queue.async {
            if self.isStopped {
                return
            }

            self.isStopped = true
            self.didStop()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        self.stop()
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        self.stop()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind device: NetService, moreComing: Bool) {
        // need to keep a reference to the device object for it to be resolved
        self.devices.append(device)
        device.delegate = self
        device.resolve(withTimeout: 5.0)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        self.stop()
    }

    func netServiceDidResolveAddress(_ device: NetService) {
        self.queue.async {
            self.didFind(device)
        }
    }
}
