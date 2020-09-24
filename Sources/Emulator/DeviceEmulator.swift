import Foundation
import Embassy
import Ambassador
import RemoteCore

public class DeviceEmulator {
    let debug = false

    // https://gist.github.com/nestserau/ce8f5e5d3f68781732374f7b1c352a5a
    private let observerLock = DispatchSemaphore(value: 1)
    private var observers = [AsyncResponseHandler]()
    func addObserver(observer: AsyncResponseHandler) {
        observerLock.wait()
        defer { observerLock.signal() }
        observers.append(observer)
    }

    func removeObserver(observer: AsyncResponseHandler) {
        observerLock.wait()
        defer { observerLock.signal() }
        if let index = observers.firstIndex(of: observer) {
            observers.remove(at: index)
        }
    }

    func didUpdateVolume() {
        observerLock.wait()
        defer { observerLock.signal() }
        for observer in observers {
            observer.sendVolume()
        }
    }

    private let volumeLock = DispatchSemaphore(value: 1)
    private var _volume = 10
    public var volume: Int {
        get {
            volumeLock.wait()
            defer { volumeLock.signal() }
            return _volume
        }
        set {
            volumeLock.wait()
            defer {
                volumeLock.signal()
                didUpdateVolume()
            }
            _volume = newValue
        }
    }

    func didUpdateState() {
        observerLock.wait()
        defer { observerLock.signal() }
        for observer in observers {
            observer.sendProgress()
        }
    }

    private let stateLock = DispatchSemaphore(value: 1)
    private var _state = RemoteCore.DeviceState.unknown
    public var state: RemoteCore.DeviceState {
        get {
            stateLock.wait()
            defer { stateLock.signal() }
            return _state
        }
        set {
            stateLock.wait()
            defer {
                stateLock.signal()
                didUpdateState()
            }
            _state = newValue
        }
    }

    let volMin = 0
    let volMax = 90
    let volMuted = false

    let router = DefaultRouter()
    var ns: NetService?
    var server: DefaultHTTPServer?
    var port: Int

    public init(port: Int) {
        self.port = port
    }

    public func run(name: String) {
        ns = NetService(domain: "local.", type: "_beoremote._tcp.", name: name, port: Int32(port))
        ns?.publish()

        if self.ns?.name == "NonRespondingDevice" {
            RunLoop.current.run()
            // never returns
        }

        if let loop = try? SelectorEventLoop(selector: try! KqueueSelector()) {
            server = DefaultHTTPServer(eventLoop: loop, interface: "localhost", port: port, app: router.app)

            if debug {
                server?.logger.add(handler: PrintLogHandler())
            }

            addRoutes()
            try! server?.start()
            loop.runForever()
        }
    }

    public func stop() {
        server?.stopAndWait()
        ns?.stop()
    }

    deinit {
        stop()
    }
}

extension DeviceEmulator {
    func getName() -> String {
        return self.ns?.name ?? "$no-name$"
    }

    func addRoutes(getDataApiEnabled : Bool = true) {
        // Play, original port: 8080
        router["/BeoZone/Zone/Stream/Play"] = JSONResponse() { environ -> Any in
            self.state = RemoteCore.DeviceState.play
            return []
        }

        // Pause, original port: 8080
        router["/BeoZone/Zone/Stream/Pause"] = JSONResponse() { environ -> Any in
            self.state = RemoteCore.DeviceState.pause
            return []
        }

        // Stop, original port: 8080
        router["/BeoZone/Zone/Stream/Stop"] = JSONResponse() { environ -> Any in
            self.state = RemoteCore.DeviceState.unknown
            return []
        }

        // Get volume, original port: 8080
        router["/BeoZone/Zone/Sound/Volume/Speaker/"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return ["speaker": ["level": self.volume]]
        }))

        // Set volume, original port: 8080
        router["/BeoZone/Zone/Sound/Volume/Speaker/Level"] = JSONResponse() { (environ, sendJSON) in
            let input = environ["swsgi.input"] as! SWSGIInput

            guard environ["HTTP_CONTENT_LENGTH"] != nil else {
                // handle error
                sendJSON([])
                return
            }

            JSONReader.read(input) { json in
                if let dict = json as? [String: Any], let level = dict["level"] as? Int {
                    self.volume = level
                }
                sendJSON([])
            }
        }

        // Notifications, original port: 8080
        // HTTP Long Polling, see https://en.wikipedia.org/wiki/Push_technology#Long_polling
        router["/BeoNotify/Notifications"] = AsyncNotificationResponse(emulator: self)

        // Get sources, original port: 8080
        router["/BeoZone/Zone/Sources"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return ["sources": [[
                "radio:1234.1234567.12345678@products.bang-olufsen.com",
                [
                    "id": "radio:1234.1234567.12345678@products.bang-olufsen.com",
                    "jid": "1234.1234567.12345678@products.bang-olufsen.com",
                    "sourceType": ["type": "TUNEIN"],
                    "category": "RADIO",
                    "friendlyName": "TuneIn",
                    "borrowed": false,
                    "product": [
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
                    "product": [
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
                    "product": [
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
                    "product": [
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
                    "product": [
                        "jid": "9999.1234567.12345678@products.bang-olufsen.com",
                        "friendlyName": "Living Room"
                    ]
                ]
            ]]]
        }))

        // Get controlled sources, original port: 80 <-- heads up
        if (getDataApiEnabled) {
            router["/api/getData"] = DelayResponse(JSONResponse(handler: { _ -> Any in
                return [["type": "controlledSources", "controlledSources": [
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
                ]]]
            }))

        } else {

            router["/api/getData"] = DataResponse(statusCode: 500, contentType: "application/json; charset=UTF-8") { environ -> Data in
                return Data("{\"error\":{\"message\":\"Error: path not whitelisted!\",\"name\":\"error\"}}".utf8)
            }
        }

        // Get TuneIn favorite stations, original port: 8080
        router["/BeoContent/radio/netRadioProfile/favoriteList/id=f1/favoriteListStation"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "favoriteListStationList": [
                    "offset": 0,
                    "count": 3,
                    "total": 3,
                    "favoriteListStation": [
                        [
                            "id": "id%3df1_0",
                            "number": 1,
                            "station": [
                                "id": "id%3df1_0",
                                "name": "90.8 | DR P1",
                                "tuneIn": [
                                    "stationId": "s24860",
                                    "location": ""
                                ],
                                "image": [
                                    [
                                        "url": "http://cdn-profiles.tunein.com/s24860/images/logog.png",
                                        "size": "large",
                                        "mediatype": "image/png"
                                    ]
                                ]
                            ],
                            "_links": [
                                "self": [
                                    "href": "./id%3df1_0"
                                ]
                            ]
                        ],
                        [
                            "id": "id%3df1_1",
                            "number": 2,
                            "station": [
                                "id": "id%3df1_1",
                                "name": "DR P2 Klassisk (Classical Music)",
                                "tuneIn": [
                                    "stationId": "s37197",
                                    "location": ""
                                ],
                                "image": [
                                    [
                                        "url": "http://cdn-profiles.tunein.com/s37197/images/logog.png",
                                        "size": "large",
                                        "mediatype": "image/png"
                                    ]
                                ]
                            ],
                            "_links": [
                                "self": [
                                    "href": "./id%3df1_1"
                                ]
                            ]
                        ],
                        [
                            "id": "id%3df1_2",
                            "number": 3,
                            "station": [
                                "id": "id%3df1_2",
                                "name": "93.9 | DR P3 (Euro Hits)",
                                "tuneIn": [
                                    "stationId": "s24861",
                                    "location": ""
                                ],
                                "image": [
                                    [
                                        "url": "http://cdn-profiles.tunein.com/s24861/images/logog.png",
                                        "size": "large",
                                        "mediatype": "image/png"
                                    ]
                                ]
                            ],
                            "_links": [
                                "self": [
                                    "href": "./id%3df1_2"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        }))

        router["/hello-world"] = DataResponse(statusCode: 200, contentType: "text/html; charset=UTF-8") { environ -> Data in
            return Data("<h1>beoplay-cli emulator: \(self.getName())</h1>".utf8)
        }
    }
}
