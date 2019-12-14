import Foundation
import Ambassador

public class AsyncNotificationResponse : WebApp {
    private let lock = DispatchSemaphore(value: 1)
    private var counter = 0
    let emulator: DeviceEmulator

    public init(emulator: DeviceEmulator) {
        self.emulator = emulator
    }

    // https://gist.github.com/nestserau/ce8f5e5d3f68781732374f7b1c352a5a
    public func incrementAndGetCounter() -> Int {
        lock.wait()
        defer { lock.signal() }
        counter += 1
        return counter
    }

    public func app(
        _ environ: [String: Any],
        startResponse: ((String, [(String, String)]) -> Void),
        sendBody: @escaping ((Data) -> Void)
    ) {
        startResponse("200 OK", [("contentType", "application/json")])
        let handler = AsyncResponseHandler(app: self, environ: environ, sendBody: sendBody)
        handler.sendVolume()
        emulator.addObserver(observer: handler)

        // Push out progress updates for 5 minutes
        // See https://en.wikipedia.org/wiki/Push_technology#Long_polling
        handler.startProgressLoop(limit: 5*60)
    }
}
