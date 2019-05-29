import Foundation

public final class RemoteControl {
    private let baseurl: String

    public init() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

        self.baseurl = "http://192.168.1.20:8080"
    }

    private func request(path: String, method: String) {
        let sema = DispatchSemaphore( value: 0)

        let url = URL(string: self.baseurl + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            sema.signal(); // signals the process to continue
        };

        task.resume()
        sema.wait() // sets the process to wait
    }

    public func play() throws {
        print("play()")
        request(path: "/BeoZone/Zone/Stream/Play", method: "POST");
        request(path: "/BeoZone/Zone/Stream/Play/Release", method: "POST");
    }

    public func pause() throws {
        print("pause()")
        request(path: "/BeoZone/Zone/Stream/Pause", method: "POST");
        request(path: "/BeoZone/Zone/Stream/Pause/Release", method: "POST");
    }

    public func stop() throws {
        print("stop()")
        request(path: "/BeoZone/Zone/Stream/Stop", method: "POST");
        request(path: "/BeoZone/Zone/Stream/Stop/Release", method: "POST");
    }

    public func forward() throws {
        print("forward()")
        request(path: "/BeoZone/Zone/Stream/Forward", method: "POST");
        request(path: "/BeoZone/Zone/Stream/Forward/Release", method: "POST");
    }

    public func backward() throws {
        print("backward()")
        request(path: "/BeoZone/Zone/Stream/Backward", method: "POST");
        request(path: "/BeoZone/Zone/Stream/Backward/Release", method: "POST");
    }

}