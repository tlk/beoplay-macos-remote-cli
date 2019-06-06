import Foundation
import SwiftyJSON

public class RemoteControl {
    private var components = URLComponents()
    private var remoteNotificationsSession: RemoteNotificationsSession?

    public init() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)

        self.components.scheme = UserDefaults.standard.string(forKey: "scheme") ?? "http"
        self.components.host = UserDefaults.standard.string(forKey: "host") ?? "192.168.1.20"

        let port = UserDefaults.standard.integer(forKey: "port")
        self.components.port = port > 0 ? port : 8080
    }

    private func request(path: String, 
            method: String, 
            body: String? = nil, 
            completionData: ((Data?) -> ())? = nil, 
            _ completion: (() -> ())? = nil) {

        var urlComponents = self.components
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
        func volumeFragmentReader(data: Data) {
            if let json = try? JSON(data: data) {
                if json["notification"]["type"].stringValue == "VOLUME" {
                    if let volume = Int(json["notification"]["data"]["speaker"]["level"].stringValue) {
                        volumeUpdate(volume)
                    }
                }
            }
        }

        var urlComponents = self.components
        urlComponents.path = "/BeoNotify/Notifications"
        self.remoteNotificationsSession = RemoteNotificationsSession(url: urlComponents.url!, fragmentReader: volumeFragmentReader, connectionCallback: connectionUpdate)
        self.remoteNotificationsSession?.start()
    }

    public func stopVolumeNotifications() {
        self.remoteNotificationsSession?.stop()
    }
}