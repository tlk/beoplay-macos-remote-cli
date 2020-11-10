import Foundation
import Embassy
import RemoteCore

public class AsyncResponseHandler : NSObject {
    let app: AsyncNotificationResponse
    let environ: [String: Any]
    var sendBody: (Data) -> Void
    var loop: EventLoop
    let updateInterval = TimeInterval(1.0)
    var limit = 0

    private let lock = DispatchSemaphore(value: 1)
    private var _counter = 0

    // https://gist.github.com/nestserau/ce8f5e5d3f68781732374f7b1c352a5a
    func incrementAndGetCounter() -> Int {
        lock.wait()
        defer { lock.signal() }
        _counter += 1
        return _counter
    }

    func getCounter() -> Int {
        lock.wait()
        defer { lock.signal() }
        return _counter
    }

    // https://stackoverflow.com/a/28016692/936466
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    func getIso8601Timestamp() -> String {
        AsyncResponseHandler.iso8601.string(from: Date())
    }

    init(app: AsyncNotificationResponse, environ: [String: Any], sendBody: @escaping ((Data) -> Void)) {
        self.app = app
        self.environ = environ
        self.sendBody = sendBody
        self.loop = environ["embassy.event_loop"] as! EventLoop
    }

    deinit {
        app.emulator.removeObserver(observer: self)
    }

    func startProgressLoop(limit: Int) {
        self.limit = limit
        progressLoop()
    }

    func progressLoop() {
        sendProgress()

        // Terminate after limit seconds
        guard getCounter() <= limit else {
            app.emulator.removeObserver(observer: self)
            sendBody(Data())
            return
        }

        loop.call(withDelay: updateInterval) {
            self.progressLoop()
        }
    }

    func sendProgress() {
        sendProgress(state: app.emulator.state.rawValue)
    }

    func sendProgress(state: String) {
        let obj = ["notification": [
            "type": "PROGRESS_INFORMATION",
            "id": app.incrementAndGetCounter(),
            "timestamp": getIso8601Timestamp(),
            "kind": "playing",
            "data": [
                "state": state,
                "position": incrementAndGetCounter(),
                "totalDuration": limit,
                "seekSupported": false,
                "playQueueItemId": "plid-000"
            ]
        ]]

        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            sendBody(data)
            sendBody(Data("\n\n".utf8))
        }
    }

    func sendVolume() {
        sendVolume(volume: app.emulator.volume)
    }

    func sendVolume(volume: Int) {
        let obj = ["notification": [
            "type": "VOLUME",
            "id": app.incrementAndGetCounter(),
            "timestamp": getIso8601Timestamp(),
            "kind": "renderer",
            "data": [
                "speaker": [
                    "level": volume,
                    "muted": app.emulator.volMuted,
                    "range": [
                        "minimum": app.emulator.volMin,
                        "maximum": app.emulator.volMax
                    ]
                ]
            ]
        ]]

        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            sendBody(data)
            sendBody(Data("\n\n".utf8))
        }
    }
}
