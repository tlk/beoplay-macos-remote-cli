import Foundation

public class RemoteNotificationsSession : NSObject, URLSessionDataDelegate {
    private let url: URL
    private let fragmentReader: (Data) -> Void
    private let connectionCallback: (ConnectionState) -> Void
    private var shutdown = false
    private var state = ConnectionState.offline
    private var backoff = 1

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = TimeInterval(3)
        //configuration.timeoutIntervalForResource = TimeInterval(5)
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private func updateConnectionState(state: ConnectionState) {
        if self.state != state {
            self.connectionCallback(state)
            self.state = state
        }
    }

    public enum ConnectionState: Int {
        case offline = 1
        case connecting = 2
        case reconnecting = 3
        case disconnecting = 4
        case online = 5
    }

    public init(url: URL, fragmentReader: @escaping (Data) -> Void, connectionCallback: @escaping (ConnectionState) -> Void) {
        self.url = url
        self.fragmentReader = fragmentReader
        self.connectionCallback = connectionCallback
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.fragmentReader(data)
        self.updateConnectionState(state: ConnectionState.online)
        self.backoff = 1
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            //print("error: \(error!)")
        }

        self.updateConnectionState(state: ConnectionState.offline)
        self.reconnect()
    }

    private func reconnect() {
        if !self.shutdown {
            self.updateConnectionState(state: ConnectionState.reconnecting)
            let ms = UInt32(self.backoff * 1000000)
            //print("usleep(\(ms))")
            usleep(ms)
            if self.backoff < 125 {
                self.backoff *= 5
            }
            self.start()
        }
    }

    public func start() {
        self.updateConnectionState(state: ConnectionState.connecting)
        let task = self.session.dataTask(with: self.url)
        task.resume()
    }

    public func stop() {
        self.shutdown = true
        self.updateConnectionState(state: ConnectionState.disconnecting)
        self.session.invalidateAndCancel()
        self.updateConnectionState(state: ConnectionState.offline)
    }
}