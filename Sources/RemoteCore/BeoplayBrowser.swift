import Foundation

public class BeoplayBrowser {
    private var queue = DispatchQueue(label: "beoplay-browser", attributes: .concurrent)
    private var browser = NetServiceBrowser()

    public func searchForDevices(delegate: NetServiceBrowserDelegate, withTimeout: TimeInterval? = nil, next: (() -> ())? = nil) {

        if withTimeout != nil {
            self.queue.asyncAfter(deadline: .now() + withTimeout!) {
                self.browser.stop()
                next?()
            }
        }

        self.queue.async {
            self.browser.delegate = delegate
            self.browser.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
            self.browser.searchForServices(ofType: "_beoremote._tcp.", inDomain: "local.")
            RunLoop.current.run()
        }
    }

    public func stop() {
        self.browser.stop()
    }
}
