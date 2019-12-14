import Foundation
import SwiftyJSON

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
        if let lines = preProcess(data) {
            self.bridge(lines)
        }
    }

    // Data consists of json objects separated with line breaks.
    // Some objects are broken into multiple lines, so let's handle that.
    private var lastLine = ""
    private func preProcess(_ data: Data) -> [JSON]? {
        let chunk = String(decoding: data, as: UTF8.self)
        let lines = chunk.split { $0.isNewline }

        return lines.compactMap() { subStr in
            let line = String(subStr)

            let json = JSON(data: Data(line.utf8))
            if json["notification"]["type"].string != nil {
                lastLine = ""
                return json
            } else if lastLine.isEmpty == false {
                let opt = lastLine + line
                let json = JSON(data: Data(opt.utf8))
                if json["notification"]["type"].string != nil {
                    lastLine = ""
                    return json
                }
            }

            lastLine = line
            return nil
        }
    }

    private func bridge(_ notifications: [JSON]) {
        for json in notifications {

            if json["notification"]["type"].stringValue == "VOLUME" {
                let volume = json["notification"]["data"]["speaker"]["level"].intValue
                let muted = json["notification"]["data"]["speaker"]["muted"].boolValue
                let minimum = json["notification"]["data"]["speaker"]["range"]["minimum"].intValue
                let maximum = json["notification"]["data"]["speaker"]["range"]["maximum"].intValue
                let data = Volume(volume: volume, muted: muted, minimum: minimum, maximum: maximum)
                NotificationCenter.default.post(name: .onVolumeChange, object: self, userInfo: ["data": data])

            } else if json["notification"]["type"].stringValue == "PROGRESS_INFORMATION" {
                let playQueueItemId = json["notification"]["data"]["playQueueItemId"].stringValue
                let strState = json["notification"]["data"]["state"].stringValue
                let state = DeviceState.init(rawValue: strState) ?? DeviceState.unknown
                let data = Progress(playQueueItemId: playQueueItemId, state: state)
                NotificationCenter.default.post(name: .onProgress, object: self, userInfo: ["data": data])

            } else if json["notification"]["type"].stringValue == "SOURCE" {
                let id = json["notification"]["data"]["primary"].stringValue
                let type = json["notification"]["data"]["primaryExperience"]["source"]["sourceType"]["type"].stringValue
                let category = json["notification"]["data"]["primaryExperience"]["source"]["category"].stringValue
                let friendlyName = json["notification"]["data"]["primaryExperience"]["source"]["friendlyName"].stringValue
                let productJid = json["notification"]["data"]["primaryExperience"]["source"]["product"]["jid"].stringValue
                let productFriendlyName = json["notification"]["data"]["primaryExperience"]["source"]["product"]["friendlyName"].stringValue
                let strState = json["notification"]["data"]["primaryExperience"]["state"].stringValue
                let state = DeviceState.init(rawValue: strState) ?? DeviceState.unknown
                let data = Source(id: id, type: type, category: category, friendlyName: friendlyName, productJid: productJid, productFriendlyName: productFriendlyName, state: state)
                NotificationCenter.default.post(name: .onSourceChange, object: self, userInfo: ["data": data])

            } else if json["notification"]["type"].stringValue == "NOW_PLAYING_NET_RADIO" {
                let stationId = json["notification"]["data"]["stationId"].stringValue
                let liveDescription = json["notification"]["data"]["liveDescription"].stringValue
                let name = json["notification"]["data"]["name"].stringValue
                let data = NowPlayingRadio(stationId: stationId, liveDescription: liveDescription, name: name)
                NotificationCenter.default.post(name: .onNowPlayingRadio, object: self, userInfo: ["data": data])

            } else if json["notification"]["type"].stringValue == "NOW_PLAYING_STORED_MUSIC" {
                let name = json["notification"]["data"]["name"].stringValue
                let artist = json["notification"]["data"]["artist"].stringValue
                let album = json["notification"]["data"]["album"].stringValue
                let data = NowPlayingStoredMusic(name: name, artist: artist, album: album)
                NotificationCenter.default.post(name: .onNowPlayingStoredMusic, object: self, userInfo: ["data": data])
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
