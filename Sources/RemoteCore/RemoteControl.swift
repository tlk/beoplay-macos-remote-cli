import Foundation
import SwiftyJSON

public class RemoteControl {
    private var endpoint = URLComponents()
    private var remoteNotificationsSession: RemoteNotificationsSession?

    public init() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

        self.endpoint.scheme = "http"
    }

    private func request(path: String, 
            method: String, 
            body: String? = nil, 
            completionData: ((Data?) -> ())? = nil, 
            _ completion: (() -> ())? = nil) {

        var urlComponents = self.endpoint
        urlComponents.path = path
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.httpBody = body?.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            completionData?(data)
            completion?()
        };

        task.resume()
    }

    public func discover(_ completion: @escaping () -> () = {}, callback: @escaping (NetService) -> ()) {
        let bonjour = BonjourBrowser(completion, callback: callback)
        bonjour.discoverServices()
    }

    public func setEndpoint(host: String, port: Int) {
        self.endpoint.host = host
        self.endpoint.port = port
    }

    public func play(_ completion: @escaping () -> () = {}) {
        request(path: "/BeoZone/Zone/Stream/Play", method: "POST", completion);
        request(path: "/BeoZone/Zone/Stream/Play/Release", method: "POST");
    }

    public func pause(_ completion: @escaping () -> () = {}) {
        request(path: "/BeoZone/Zone/Stream/Pause", method: "POST", completion);
        request(path: "/BeoZone/Zone/Stream/Pause/Release", method: "POST");
    }

    public func stop(_ completion: @escaping () -> () = {}) {
        request(path: "/BeoZone/Zone/Stream/Stop", method: "POST", completion);
        request(path: "/BeoZone/Zone/Stream/Stop/Release", method: "POST");
    }

    public func forward(_ completion: @escaping () -> () = {}) {
        request(path: "/BeoZone/Zone/Stream/Forward", method: "POST", completion);
        request(path: "/BeoZone/Zone/Stream/Forward/Release", method: "POST");
    }

    public func backward(_ completion: @escaping () -> () = {}) {
        request(path: "/BeoZone/Zone/Stream/Backward", method: "POST", completion);
        request(path: "/BeoZone/Zone/Stream/Backward/Release", method: "POST");
    }

    public func getVolume(_ completion: @escaping (Int?) -> ()) {
        func getVolumeFromJSON(_ data: Data?) -> Int? {
            var volume: Int?
            if let json = try? JSON(data: data!) {
                volume = Int(json["speaker"]["level"].stringValue)
            }
            return volume
        }

        func completionData(data: Data?) {
            let vol = getVolumeFromJSON(data)
            completion(vol)
        }

        request(path: "/BeoZone/Zone/Sound/Volume/Speaker/", method: "GET", completionData: completionData)
    }

    public func setVolume(volume: Int, _ completion: @escaping () -> () = {}) {
        request(path: "/BeoZone/Zone/Sound/Volume/Speaker/Level", method: "PUT", body: "{\"level\":\(volume)}", completion)
    }

    public func receiveVolumeNotifications(volumeUpdate: @escaping (Int) -> (), connectionUpdate: @escaping (RemoteNotificationsSession.ConnectionState, String?) -> ()) {
        func volumeChunkReader(data: Data) {
            let chunk = String(decoding: data, as: UTF8.self)
            let lines = chunk.split { $0.isNewline }

            for line in lines {
                let json = JSON(parseJSON: String(line))
                if json["notification"]["type"].stringValue == "VOLUME" {
                    if let volume = Int(json["notification"]["data"]["speaker"]["level"].stringValue) {
                        volumeUpdate(volume)
                    }
                }
            }
        }

        var urlComponents = self.endpoint
        urlComponents.path = "/BeoNotify/Notifications"
        self.remoteNotificationsSession = RemoteNotificationsSession(url: urlComponents.url!, chunkReader: volumeChunkReader, connectionCallback: connectionUpdate)
        self.remoteNotificationsSession?.start()
    }

    public func stopVolumeNotifications() {
        self.remoteNotificationsSession?.stop()
    }
}