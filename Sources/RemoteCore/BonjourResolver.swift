import Foundation

class BonjourResolver : NSObject, NetServiceDelegate {
    let timeout: CFTimeInterval = 1

    var runLoop: CFRunLoop = CFRunLoopGetCurrent()
    var callback: (NetService) -> ()

    public init(_ callback: @escaping (NetService) -> ()) {
        self.callback = callback
    }

    public func resolve(_ service: NetService) {
        service.delegate = self
        service.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        service.resolve(withTimeout: self.timeout)
        CFRunLoopRun()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        CFRunLoopStop(self.runLoop)
    }

    func netServiceDidStop(_ sender: NetService) {
        CFRunLoopStop(self.runLoop)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        self.callback(sender)
        CFRunLoopStop(self.runLoop)
    }
}