import Foundation

public class RemoteControl {
    private var endpoint = URLComponents()
    private var notificationSession: NotificationSession?
    private var remoteAdmin = RemoteAdminControl()
    private let browser = BeoplayBrowser()

    public init() {
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
    }

    private func request(method: String, path: String, query: String? = nil, body: String? = nil, _ completion: (() -> ())? = nil) {
        request(method: method, path: path, query: query, body: body) { _ in
            completion?()
        }
    }

    private func request(method: String, path: String, query: String? = nil, body: String? = nil, completionData: ((Data?) -> ())? = nil) {
        var urlComponents = self.endpoint
        urlComponents.path = path
        urlComponents.query = query

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = method
        request.httpBody = body?.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            completionData?(data)
        };

        task.resume()
    }

    public func startDiscovery(delegate: NetServiceBrowserDelegate, withTimeout: TimeInterval? = nil, next: (() -> ())? = nil) {
        browser.searchForDevices(delegate: delegate, withTimeout: withTimeout, next: next)
    }

    public func stopDiscovery() {
        browser.stop()
    }

    public func setEndpoint(host: String, port: Int, adminPort: Int = 80) {
        self.endpoint.host = host
        self.endpoint.port = port
        self.endpoint.scheme = "http"
        self.remoteAdmin.setEndpoint(host: host, port: adminPort)
    }

    public func clearEndpoint() {
        self.endpoint.host = nil
        self.endpoint.port = nil
        self.remoteAdmin.clearEndpoint()
    }

    public func hasEndpoint() -> Bool {
        return self.endpoint.host != nil
    }

    public func getSources(_ completion: @escaping ([BeoplaySource]) -> ()) {
        func completionData(data: Data?) {
            var sources = [BeoplaySource]()

            guard let json = JSON.from(input: data),
                  let list = json.getAny(at: ["sources"]) as? [[Any]] else {
                completion(sources)
                return
            }

            for element in list {
                guard element.count > 1,
                    let id = element.first as? String,
                    let second = element.dropFirst().first
                else {
                    continue
                }

                let details = JSON(from: second)

                if let sourceType = details.getString(at: ["sourceType", "type"]),
                   let category = details.getString(at: ["category"]),
                   let friendlyName = details.getString(at: ["friendlyName"]),
                   let borrowed = details.getBool(at: ["borrowed"]),
                   let productJid = details.getString(at: ["product", "jid"]),
                   let productFriendlyName = details.getString(at: ["product", "friendlyName"]) {

                    let source = BeoplaySource(
                        id: id,
                        sourceType: sourceType,
                        category: category,
                        friendlyName: friendlyName,
                        borrowed: borrowed,
                        productJid: productJid,
                        productFriendlyName: productFriendlyName
                    )
                    sources.append(source)
                }

            }
            completion(sources)
        }

        request(method: "GET", path: "/BeoZone/Zone/Sources", completionData: completionData)
    }

    public func getEnabledSources(_ completion: @escaping ([BeoplaySource]) -> ()) {
        self.remoteAdmin.getEnabledControlledSourceIds { (enabledSourceIds: [String]) -> () in
            self.getSources { (sources: [BeoplaySource]) -> () in
                var result = [BeoplaySource]()
                if enabledSourceIds.isEmpty {
                    // fallback fx for Beosound Moment
                    result = sources
                } else {
                    for id in enabledSourceIds {
                        let isBorrowed = id.contains(":")
                        for source in sources {
                            let sourceId = isBorrowed ? id : "\(id):\(source.productJid)"
                            if sourceId == source.id && isBorrowed == source.borrowed {
                                result.append(source)
                            }
                        }
                    }
                }

                completion(result)
            }
        }
    }

    public func setSource(id: String, _ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/ActiveSources", body: "{\"primaryExperience\":{\"source\":{\"id\":\"\(id)\"}}}", completion)
    }

    public func setSourceAndContent(sourceId: String, contentId: String, _ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/ActiveSources", body: "{\"primaryExperience\":{\"source\":{\"id\":\"\(sourceId)\"}},\"contentId\":\"\(contentId)\"}", completion)
    }

    public func getRadioFavorites(_ completion: @escaping (_ favorites: [(String, String)]) -> ()) {
        var favorites = [(String, String)]()
        request(method: "GET", path: "/BeoContent/radio/netRadioProfile/favoriteList/favorite/favoriteListStation") { data in

            if let json = JSON.from(input: data),
               let list = json.getAny(at: ["favoriteListStationList", "favoriteListStation"]) as? [Any] {

                for station in list {
                    let details = JSON(from: station)
                    if let stationId = details.getString(at:["station", "beoradio", "stationId"]),
                       let stationName = details.getString(at:["station", "name"]) {
                        favorites.append((stationId, stationName))
                    }
                }
            }

            completion(favorites)
        }
    }

    public func join(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Device/OneWayJoin", completion);
    }

    public func leave(_ completion: @escaping () -> () = {}) {
        request(method: "DELETE", path: "/BeoZone/Zone/ActiveSources/primaryExperience", completion);
    }

    public func play(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Play") {
            self.request(method: "POST", path: "/BeoZone/Zone/Stream/Play/Release", completion)
        }
    }

    public func pause(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Pause") {
            self.request(method: "POST", path: "/BeoZone/Zone/Stream/Pause/Release", completion)
        }
    }

    public func stop(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Stop") {
            self.request(method: "POST", path: "/BeoZone/Zone/Stream/Stop/Release", completion)
        }
    }

    public func next(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Forward") {
            self.request(method: "POST", path: "/BeoZone/Zone/Stream/Forward/Release", completion)
        }
    }

    public func back(_ completion: @escaping () -> () = {}) {
        request(method: "POST", path: "/BeoZone/Zone/Stream/Backward") {
            self.request(method: "POST", path: "/BeoZone/Zone/Stream/Backward/Release", completion)
        }
    }

    public func getVolume(_ completion: @escaping (Int?) -> ()) {
        func getVolumeFromJSON(_ data: Data?) -> Int? {
            if let json = JSON.from(input: data),
               let volume = json.getInt(at: ["speaker", "level"])
            {
                return volume
            }
            else {
                return nil
            }
        }

        func completionData(data: Data?) {
            let vol = getVolumeFromJSON(data)
            completion(vol)
        }

        request(method: "GET", path: "/BeoZone/Zone/Sound/Volume/Speaker/", completionData: completionData)
    }

    public func setVolume(volume: Int, _ completion: @escaping () -> () = {}) {
        var vol = max(0, volume)
        vol = min(100, vol)
        request(method: "PUT", path: "/BeoZone/Zone/Sound/Volume/Speaker/Level", body: "{\"level\":\(vol)}", completion)
    }

    public func adjustVolume(delta: Int, _ completion: @escaping () -> () = {}) {
        self.getVolume { volume in
            guard let vol = volume else {
                return
            }
            self.setVolume(volume: vol + delta, completion)
        }
    }

    public func mute(_ completion: @escaping () -> () = {}) {
        request(method: "PUT", path: "/BeoZone/Zone/Sound/Volume/Speaker/Muted", body: "{\"muted\":true}", completion)
    }

    public func unmute(_ completion: @escaping () -> () = {}) {
        request(method: "PUT", path: "/BeoZone/Zone/Sound/Volume/Speaker/Muted", body: "{\"muted\":false}", completion)
    }

    public func startNotifications() {
        var urlComponents = self.endpoint
        urlComponents.path = "/BeoNotify/Notifications"

        self.notificationSession = NotificationSession(url: urlComponents.url!, processor: NotificationBridge())
        self.notificationSession?.start()
    }

    public func stopNotifications() {
        self.notificationSession?.stop()
    }
}
