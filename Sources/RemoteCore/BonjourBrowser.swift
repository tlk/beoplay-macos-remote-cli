import Foundation

class BonjourBrowser : NSObject, NetServiceBrowserDelegate {
    let serviceType = "_beoremote._tcp."
    let domain = "local."
    let timeout: CFTimeInterval = 1

    var callback: (NetService) -> ()
    var completion: () -> () = {}
    var browser = NetServiceBrowser()
    var runLoop: CFRunLoop = CFRunLoopGetCurrent()

    public init(_ completion: @escaping () -> () = {}, callback: @escaping (NetService) -> ()) {
        self.completion = completion
        self.callback = callback
    }

    public func discoverServices() {
        // A RunLoop is required by NetServiceBrowser but the RunLoop itself has no exit mechanism.
        // Fortunately, it is possible to use the lower level CFRunLoopRunInMode mechanism 
        // that makes it possible to provide a timeout and to exit the runloop with CFRunLoopStop.
        //                                      See https://stackoverflow.com/q/8590546/936466

        self.runLoop = CFRunLoopGetCurrent()
        self.browser = NetServiceBrowser()
        self.browser.delegate = self
        self.browser.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        self.browser.searchForServices(ofType: self.serviceType, inDomain: self.domain)
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, self.timeout, false)
        self.completion()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        CFRunLoopStop(self.runLoop)
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        CFRunLoopStop(self.runLoop)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind svc: NetService, moreComing: Bool) {
        let bonjour = BonjourResolver(self.callback)
        bonjour.resolve(svc)

        if moreComing == false {
            CFRunLoopStop(self.runLoop)
        }
    }
}