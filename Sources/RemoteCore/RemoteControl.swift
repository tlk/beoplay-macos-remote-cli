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

    private func request(method: String,
            path: String,
            query: String? = nil,
            body: String? = nil, 
            completionData: ((Data?) -> ())? = nil, 
            _ completion: (() -> ())? = nil) {

        var urlComponents = self.endpoint
        urlComponents.path = path
        urlComponents.query = query
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = method
        request.httpBody = body?.data(using: .utf8)

        // print("request: \(request)")

        // let session: URLSession = {
        //     let configuration = URLSessionConfiguration.default
        //     configuration.connectionProxyDictionary = [AnyHashable: Any]()
        //     configuration.connectionProxyDictionary?[kCFNetworkProxiesHTTPEnable as String] = 1
        //     configuration.connectionProxyDictionary?[kCFNetworkProxiesHTTPProxy as String] = "192.168.1.232"
        //     configuration.connectionProxyDictionary?[kCFNetworkProxiesHTTPPort as String] = 8080
        //     return URLSession(configuration: configuration)
        // }()

        //let task = session.dataTask(with: request) { (data, response, error) in
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            // let debug = JSON(data!)
            // print ("response: \(debug)")

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
        request(method: "POST", path: "/BeoZone/Zone/Stream/Play", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Play/Release");
    }

    public func pause(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Pause", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Pause/Release");
    }

    public func stop(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Stop", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Stop/Release");
    }

    public func forward(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Forward", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Forward/Release");
    }

    public func backward(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Backward", completion);
        request(method: "POST", path: "/BeoZone/Zone/Stream/Backward/Release");
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

        request(method: "GET", path: "/BeoZone/Zone/Sound/Volume/Speaker/", completionData: completionData)
    }

    public func setVolume(volume: Int, _ completion: @escaping () -> () = {}) {
        request(method: "PUT", path: "/BeoZone/Zone/Sound/Volume/Speaker/Level", body: "{\"level\":\(volume)}", completion)
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

    public func getSources(_ completion: @escaping (Dictionary<String, String>) -> ()) {
        func completionData(data: Data?) {
            var sources: [String: String] = [:]

            if let json = try? JSON(data: data!) {
                for (_, source) in json["sources"] {
                    let friendlyName = source[1]["friendlyName"].string
                    let id = source[1]["id"].string
                    sources[friendlyName!] = id
                }
            }

            completion(sources)
        }

        request(method: "GET", path: "/BeoZone/Zone/Sources/", completionData: completionData)
    }

    public func setPrimaryExperience(sourceId: String, _ completion: @escaping () -> () = {}) {
        let json: JSON =
        [
            "primaryExperience": [
                "source": [
                    "id": sourceId
                ]
            ]
        ]
        let jsonString: String? = json.rawString([.castNilToNSNull: true])
        print("json: \(jsonString!)")

        request(method: "DELETE", path: "/BeoZone/Zone/ActiveSources/primaryExperience");
        request(method: "POST", path: "/BeoZone/Zone/ActiveSources", body: jsonString, completion);
    }

    public func tuneIn(id: Int, _ completion: @escaping () -> () = {}) {
        let tuneInId = "s\(id)"
        let json: JSON =
        [
            "playQueueItem": [
                "behaviour": "planned",
                "id": tuneInId,
                "station": [
                    "id": tuneInId,
                    "image": [
                        [
                            "mediatype": "image/jpg",
                            "size": "medium",
                            "url": "https://cdn-profiles.tunein.com/s45455/images/logog.png?tlk_was_here"
                        ]                
                    ],
                    "name": "tlk was here",
                    "tuneIn": [ 
                        "location": "",
                        "stationId": tuneInId
                    ]
                ]
            ]
        ]

        request(method: "DELETE", path: "/BeoZone/Zone/PlayQueue/");
        let jsonString: String? = json.rawString([.castNilToNSNull: true])
        request(method: "POST", path: "/BeoZone/Zone/PlayQueue/", query: "instantplay", body: jsonString, completion);
    }

}