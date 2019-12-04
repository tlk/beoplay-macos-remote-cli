import Foundation
import Kitura
import SwiftyJSON

public class DeviceEmulator {
    public struct VolumeSpeakerLevel: Codable {
        public var level: Int
    }

    public struct VolumeSpeaker: Codable {
        public var speaker: VolumeSpeakerLevel
    }

    public struct VolumeNotificationType: Codable {
        public let type = "VOLUME"
        public var data: VolumeSpeaker
    }

    public struct VolumeNotification: Codable {
        public var notification: VolumeNotificationType
    }

    let router = Router()
    var ns: NetService?
    var volumeLevel = 10

    public init() {
        router.get("/") { request, response, next in
            response.send("<h1>beoplay-cli emulator: \(self.getName())</h1>")
            next()
        }

        func logger(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
            print("")
            print("\(request.method): \(request.urlURL)")

            // Do not use request.readString() in this logger as it will empty the stream
            // and leave nothing but an empty stream for remaining handlers.
            // See https://github.com/IBM-Swift/Kitura/issues/1233

            next()
        }

        router.get(handler: logger)
        router.post(handler: logger)
        router.put(handler: logger)

        router.get("/BeoZone/Zone/Sources") { request, response, next in
            let sources = ["sources": [
                [
                    "radio:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "radio:1234.1234567.12345678@products.bang-olufsen.com",
                        "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "TUNEIN"],
                        "category": "RADIO",
                        "friendlyName": "TuneIn",
                        "borrowed": false,
                        "product": 
                        [
                            "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "linein:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "linein:1234.1234567.12345678@products.bang-olufsen.com",
                        "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "LINE IN"],
                        "category": "MUSIC",
                        "friendlyName": "Line-In",
                        "borrowed": false,
                        "product": 
                        [
                            "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "bluetooth:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "bluetooth:1234.1234567.12345678@products.bang-olufsen.com",
                        "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "BLUETOOTH"],
                        "category": "MUSIC",
                        "friendlyName": "Bluetooth",
                        "borrowed": false,
                        "product":
                        [
                            "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "alarm:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "alarm:1234.1234567.12345678@products.bang-olufsen.com",
                        "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "ALARM"],
                        "category": "ALARM",
                        "friendlyName": "Alarm",
                        "borrowed": false,
                        "product": 
                        [
                            "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "spotify:9999.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "spotify:9999.1234567.12345678@products.bang-olufsen.com",
                        "jid": "9999.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "SPOTIFY"],
                        "category": "MUSIC",
                        "friendlyName": "Spotify",
                        "borrowed": true,
                        "product": 
                        [
                            "jid": "9999.1234567.12345678@products.bang-olufsen.com",
                            "friendlyName": "Living Room"
                        ]
                    ]
                ]
            ]]
            let json = JSON(sources)
            response.send(json)
            next()
        }

        router.put("/BeoZone/Zone/Sound/Volume/Speaker/Level") { request, response, next in            
            do {
                let vol = try request.read(as: VolumeSpeakerLevel.self)
                self.volumeLevel = vol.level
                print(vol)
                response.send(vol)
            } catch {
                print("unexpected error: \(error)")
            }
            next()
        }

        router.get("/BeoZone/Zone/Sound/Volume/Speaker/") { request, response, next in
            let result = VolumeSpeaker(
                speaker: VolumeSpeakerLevel(
                    level: self.volumeLevel
                )
            )
            print(result)
            response.send(result)
            next()
        }

        router.get("/BeoNotify/Notifications") { request, response, next in
            let result = VolumeNotification(
                notification: VolumeNotificationType(
                    data: VolumeSpeaker(
                        speaker: VolumeSpeakerLevel(
                            level: self.volumeLevel
                        )
                    )
                )
            )
            print(result)
            response.send(result)
            next()
        }

        // This endpoint normally lives on port 80
        router.get("/api/getData") { request, response, next in
            let result = [[
                "controlledSources": [
                    "controlledSources": [
                        [
                            "deviceId": "",
                            "enabled": false,
                            "sourceId": "linein",
                            "enabledExternal": true
                        ],
                        [
                            "deviceId": "",
                            "enabled": true,
                            "sourceId": "radio",
                            "enabledExternal": true
                        ],
                        [
                            "deviceId": "",
                            "enabled": false,
                            "sourceId": "bluetooth",
                            "enabledExternal": true
                        ],
                        [
                            "deviceId": "9999.1234567.12345678@products.bang-olufsen.com",
                            "enabled": true,
                            "sourceId": "spotify:9999.1234567.12345678@products.bang-olufsen.com",
                            "enabledExternal": false
                        ]
                    ]
                ],
                "type": "controlledSources"
            ]]

            let json = JSON(result)
            response.send(json)
            next()
        }
    }

    public func getName() -> String {
        return self.ns?.name ?? "$no-name$"
    }

    public func run(port: Int, name: String) {
        ns = NetService(domain: "local.", type: "_beoremote._tcp.", name: name, port: Int32(port))
        ns?.publish()

        if self.ns?.name == "NonRespondingDevice" {
            RunLoop.current.run()
        }

        Kitura.addHTTPServer(onPort: port, with: router)
        Kitura.run()
    }

    public func stop() {
        Kitura.stop()
        ns?.stop()
    }
}
