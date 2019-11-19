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

    public struct VolumeNotification: Codable {
        public let type = "VOLUME"
        public var data: VolumeSpeaker
    }

    let router = Router()
    var ns: NetService?
    var volumeLevel = 10

    public init() {
        router.get("/") { request, response, next in
            response.send("<h1>beoplay-cli emulator: \(self.getName())</h1>")
            next()
        }

        router.get("/BeoZone/Zone/Sources") { request, response, next in
            let sources = ["sources": [
                [
                    "radio:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "radio:1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "TUNEIN"],
                        "category": "RADIO",
                        "friendlyName": "TuneIn",
                        "product": 
                        [
                            "borrowed": "false",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "linein:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "linein:1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "LINE IN"],
                        "category": "MUSIC",
                        "friendlyName": "Line-In",
                        "product": 
                        [
                            "borrowed": "false",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "alarm:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "alarm:1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "ALARM"],
                        "category": "ALARM",
                        "friendlyName": "Alarm",
                        "product": 
                        [
                            "borrowed": "false",
                            "friendlyName": self.getName()
                        ]
                    ]
                ],
                [
                    "spotify:1234.1234567.12345678@products.bang-olufsen.com",
                    [
                        "id": "spotify:1234.1234567.12345678@products.bang-olufsen.com",
                        "sourceType": ["type": "SPOTIFY"],
                        "category": "MUSIC",
                        "friendlyName": "Spotify",
                        "product": 
                        [
                            "borrowed": "true",
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
                print("set volumeLevel: \(self.volumeLevel)")
                response.send("got it, thx")
            } catch {
                print("unexpected error: \(error)")
            }
            next()
        }

        router.get("/BeoZone/Zone/Sound/Volume/Speaker/") { request, response, next in
            print("get volumeLevel: \(self.volumeLevel)")
            let result = VolumeSpeaker(
                speaker: VolumeSpeakerLevel(
                    level: self.volumeLevel
                )
            )
            response.send(result)
            next()
        }

        router.get("/BeoNotify/Notifications") { request, response, next in
            let result = VolumeNotification(
                data: VolumeSpeaker(
                    speaker: VolumeSpeakerLevel(
                        level: self.volumeLevel
                    )
                )
            )
            response.send(result)
            next()
        }
    }

    public func getName() -> String {
        return self.ns?.name ?? "$no-name$"
    }

    public func run(port: Int, name: String) {
        ns = NetService(domain: "local.", type: "_beoremote._tcp.", name: name, port: Int32(port))
        ns?.publish()

        Kitura.addHTTPServer(onPort: port, with: router)
        Kitura.run()
    }

    public func stop() {
        Kitura.stop()
        ns?.stop()
    }
}
