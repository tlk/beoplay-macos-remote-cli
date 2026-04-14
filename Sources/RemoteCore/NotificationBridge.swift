import Foundation

extension Notification.Name {
    public static let onConnectionChange = Notification.Name("RemoteCore.onConnectionChange")
    public static let onVolumeChange = Notification.Name("RemoteCore.onVolumeChange")
    public static let onProgress = Notification.Name("RemoteCore.onProgress")
    public static let onSourceChange = Notification.Name("RemoteCore.onSourceChange")
    public static let onNowPlayingRadio = Notification.Name("RemoteCore.onNowPlayingRadio")
    public static let onNowPlayingStoredMusic = Notification.Name("RemoteCore.onNowPlayingStoredMusic")
}

public enum DeviceState : String {
    case idle, preparing, play, pause, unknown
}

public struct Volume {
    public let volume: Int
    public let muted: Bool
    public let minimum: Int
    public let maximum: Int
}

public struct Progress {
    public let playQueueItemId: String
    public let state: DeviceState
}

public struct Source {
    public let id: String
    public let type: String
    public let category: String
    public let friendlyName: String
    public let productJid: String
    public let productFriendlyName: String
    public let state: DeviceState
}

public struct NowPlayingRadio {
    public let stationId: String
    public let liveDescription: String
    public let name: String
}

public struct NowPlayingStoredMusic {
    public let name: String
    public let artist: String
    public let album: String
}

public protocol NotificationProcessor {
    func process(_ data: Data)
    func update(state: NotificationSession.ConnectionState)
    func update(state: NotificationSession.ConnectionState, message: String?)
}

public class NotificationBridge : NotificationProcessor {
    public init() {}

    public func process(_ data: Data) {
        if let jsonObjects = parseJsonObjects(data) {
            self.bridge(jsonObjects)
        }
    }

    // Data consists of json objects separated with line breaks.
    // Some objects are broken into multiple lines, so let's handle that.
    private var lastLine = ""
    private func parseJsonObjects(_ data: Data) -> [JSON]? {
        let chunk = String(decoding: data, as: UTF8.self)
        let lines = chunk.split { $0.isNewline }

        return lines.compactMap() { subStr in
            let line = String(subStr)

            if let json = parseJsonObject(from: line) {
                lastLine = ""
                return json
            } else if lastLine.isEmpty == false {
                let candidate = lastLine + line
                if let json = parseJsonObject(from: candidate) {
                    lastLine = ""
                    return json
                }
            }

            lastLine = line
            return nil
        }
    }

    private func parseJsonObject(from input: String) -> JSON? {
        guard let json = JSON.from(input: input),
              json.getString(at: ["notification", "type"]) != nil else {
            return nil
        }

        return json
    }

    private func bridge(_ notifications: [JSON]) {
        for json in notifications {
            let type = json.getString(at: ["notification", "type"])

            if type == "VOLUME" {
                if let volume = json.getInt(at: ["notification", "data", "speaker", "level"]),
                   let muted = json.getBool(at: ["notification", "data", "speaker", "muted"]),
                   let minimum = json.getInt(at: ["notification", "data", "speaker", "range", "minimum"]),
                   let maximum = json.getInt(at: ["notification", "data", "speaker", "range", "maximum"]) {

                    let data = Volume(volume: volume, muted: muted, minimum: minimum, maximum: maximum)
                    NotificationCenter.default.post(name: .onVolumeChange, object: self, userInfo: ["data": data])
                }

            } else if type == "PROGRESS_INFORMATION" {
                if let playQueueItemId = json.getString(at: ["notification", "data", "playQueueItemId"]),
                   let strState = json.getString(at: ["notification", "data", "state"]) {

                    let state = DeviceState.init(rawValue: strState) ?? DeviceState.unknown
                    let data = Progress(playQueueItemId: playQueueItemId, state: state)
                    NotificationCenter.default.post(name: .onProgress, object: self, userInfo: ["data": data])
                }

            } else if type == "SOURCE" {
                if let id = json.getString(at: ["notification", "data", "primary"]),
                   let sourceType = json.getString(at: ["notification", "data", "primaryExperience", "source", "sourceType", "type"]),
                   let category = json.getString(at: ["notification", "data", "primaryExperience", "source", "category"]),
                   let friendlyName = json.getString(at: ["notification", "data", "primaryExperience", "source", "friendlyName"]),
                   let productJid = json.getString(at: ["notification", "data", "primaryExperience", "source", "product", "jid"]),
                   let productFriendlyName = json.getString(at: ["notification", "data", "primaryExperience", "source", "product", "friendlyName"]),
                   let strState = json.getString(at: ["notification", "data", "primaryExperience", "state"]) {

                    let state = DeviceState.init(rawValue: strState) ?? DeviceState.unknown
                    let data = Source(id: id, type: sourceType, category: category, friendlyName: friendlyName, productJid: productJid, productFriendlyName: productFriendlyName, state: state)
                    NotificationCenter.default.post(name: .onSourceChange, object: self, userInfo: ["data": data])
                }

            } else if type == "NOW_PLAYING_NET_RADIO" {

                if let stationId = json.getString(at: ["notification", "data", "stationId"]),
                   let liveDescription = json.getString(at: ["notification", "data", "liveDescription"]),
                   let name = json.getString(at: ["notification", "data", "name"]) {

                    let data = NowPlayingRadio(stationId: stationId, liveDescription: liveDescription, name: name)
                    NotificationCenter.default.post(name: .onNowPlayingRadio, object: self, userInfo: ["data": data])
                }

            } else if type == "NOW_PLAYING_STORED_MUSIC" {

                if let name = json.getString(at: ["notification", "data", "name"]),
                   let artist = json.getString(at: ["notification", "data", "artist"]),
                   let album = json.getString(at: ["notification", "data", "album"]) {

                    let data = NowPlayingStoredMusic(name: name, artist: artist, album: album)
                    NotificationCenter.default.post(name: .onNowPlayingStoredMusic, object: self, userInfo: ["data": data])
                }

            }
        }
    }

    public struct DataConnectionNotification {
        public let state: NotificationSession.ConnectionState
        public let message: String?
    }

    public func update(state: NotificationSession.ConnectionState) {
        update(state: state, message: nil)
    }

    private var lastState: NotificationSession.ConnectionState = .offline
    public func update(state: NotificationSession.ConnectionState, message: String?) {
        if self.lastState != state {
            self.lastState = state
            let data = DataConnectionNotification(state: state, message: message)
            NotificationCenter.default.post(name: .onConnectionChange, object: self, userInfo: ["data": data])
        }
    }
}
