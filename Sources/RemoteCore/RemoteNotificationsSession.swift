import Foundation

public class RemoteNotificationsSession : NSObject, URLSessionDataDelegate {
    private let url: URL
    private let fragmentReader: (Data) -> ()
    private let connectionCallback: (ConnectionState, String?) -> ()
    private var shutdown = false
    private var state = ConnectionState.offline
    private var backoff = 1

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = TimeInterval(3)
        //configuration.timeoutIntervalForResource = TimeInterval(5)
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private func updateConnectionState(state: ConnectionState, message: String? = nil) {
        if self.state != state {
            self.state = state
            self.connectionCallback(state, message)
        }
    }

    public enum ConnectionState: Int {
        case offline = 1
        case connecting = 2
        case reconnecting = 3
        case disconnecting = 4
        case online = 5
    }

    public init(url: URL, fragmentReader: @escaping (Data) -> (), connectionCallback: @escaping (ConnectionState, String?) -> ()) {
        self.url = url
        self.fragmentReader = fragmentReader
        self.connectionCallback = connectionCallback
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.fragmentReader(data)

        if self.backoff != 1 {
            self.backoff = 1
            self.updateConnectionState(state: ConnectionState.online, message: "backoff reset to \(self.backoff)s")
        } else {
            self.updateConnectionState(state: ConnectionState.online)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.updateConnectionState(state: ConnectionState.offline, message: error?.localizedDescription)
        self.reconnect()
    }

    private func reconnect() {
        if !self.shutdown {
            self.updateConnectionState(state: ConnectionState.reconnecting, message: "backoff is \(self.backoff)s")
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

    public func start() {
        self.shutdown = false
        self.updateConnectionState(state: ConnectionState.connecting)
        self.session.dataTask(with: self.url).resume()
    }

    public func stop() {
        self.shutdown = true
        self.updateConnectionState(state: ConnectionState.disconnecting)
        self.session.invalidateAndCancel()
        self.updateConnectionState(state: ConnectionState.offline)
    }
}