import Foundation

public class NotificationSession : NSObject, URLSessionDataDelegate {
    private let queue = DispatchQueue.init(label: "beoplayremote-notifications-session")
    private let url: URL
    private let processor: NotificationProcessor
    private var shutdown = false
    private var backoff = 1

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = TimeInterval(3)
        //configuration.timeoutIntervalForResource = TimeInterval(5)
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    public enum ConnectionState: Int {
        case offline = 1
        case connecting = 2
        case reconnecting = 3
        case disconnecting = 4
        case online = 5
    }

    public init(url: URL, processor: NotificationProcessor) {
        self.url = url
        self.processor = processor
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if self.backoff > 5 {
            self.processor.update(state: ConnectionState.online, message: "backoff reset from \(self.backoff)s")
            self.backoff = 1
        } else {
            self.processor.update(state: ConnectionState.online)
        }

        self.processor.process(data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.processor.update(state: ConnectionState.offline, message: error?.localizedDescription)
        self.reconnect()
    }

    private func reconnect() {
        self.queue.async {
            if !self.shutdown {
                if self.backoff > 5 {
                    self.processor.update(state: ConnectionState.reconnecting, message: "backoff is \(self.backoff)s")
                }

                let ms = UInt32(self.backoff * 1000000)
                usleep(ms)

                if self.backoff < 125 {
                    self.backoff *= 5
                }

                if !self.shutdown {
                    self.start()
                }
            }
        }
    }

    public func start() {
        self.shutdown = false
        self.processor.update(state: ConnectionState.connecting)
        self.session.dataTask(with: self.url).resume()
    }

    public func stop() {
        self.shutdown = true
        self.processor.update(state: ConnectionState.disconnecting)
        self.session.invalidateAndCancel()
        self.processor.update(state: ConnectionState.offline)
    }
}
