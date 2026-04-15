import Foundation
import Embassy
import Ambassador
import RemoteCore

public class DeviceEmulator {
    let debug = false

    private let _queue = DispatchQueue(label: "device-emulator")
    private var _observers = [AsyncResponseHandler]()
    private var _volume = 10
    private var _state = RemoteCore.DeviceState.unknown

    func addObserver(observer: AsyncResponseHandler) {
        _queue.sync {
            NSLog("addObserver")
            _observers.append(observer)
        }
    }

    func removeObserver(observer: AsyncResponseHandler) {
        _queue.sync {
            NSLog("removeObserver")
            if let index = _observers.firstIndex(of: observer) {
                _observers.remove(at: index)
            }
        }
    }

    public var volume: Int {
        get {
            return _queue.sync { return _volume }
        }
        set {
            _queue.sync {
                NSLog("setVolume: \(newValue)")
                _volume = newValue
                for observer in _observers {
                    observer.sendVolume(volume: _volume)
                }
            }
        }
    }

    public var state: RemoteCore.DeviceState {
        get {
            return _queue.sync { return _state }
        }
        set {
            _queue.sync {
                NSLog("setState: \(newValue)")
                _state = newValue
                for observer in _observers {
                    observer.sendProgress(state: _state.rawValue)
                }
            }
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

        // Get B&O Radio favorite stations, original port: 8080
        router["/BeoContent/radio/netRadioProfile/favoriteList/favorite/favoriteListStation"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
              "favoriteListStationList": [
                "offset": 0,
                "count": 3,
                "total": 3,
                "favoriteListStation": [
                  [
                    "id": "6336061628069729",
                    "number": 0,
                    "station": [
                      "id": "6336061628069729",
                      "name": "DR P1",
                      "liveDescription": "DR P1 er DR's første radiokanal",
                      "beoradio": [
                        "stationId": "6336061628069729"
                      ],
                      "image": [
                        [
                          "url": "http://static.airable.io/14/37/146822.png",
                          "size": "large",
                          "mediatype": "image/png"
                        ],
                        [
                          "url": "http://static.airable.io/82/44/246012.png",
                          "size": "medium",
                          "mediatype": "image/png"
                        ],
                        [
                          "url": "http://static.airable.io/64/02/797233.png",
                          "size": "small",
                          "mediatype": "image/png"
                        ]
                      ]
                    ],
                    "_capabilities": [
                      "editable": [
                        "number"
                      ]
                    ],
                    "_links": [
                      "/relation/delete": [
                        "href": "./6336061628069729"
                      ],
                      "self": [
                        "href": "./6336061628069729"
                      ]
                    ]
                  ],
                  [
                    "id": "3666300007607788",
                    "number": 1,
                    "station": [
                      "id": "3666300007607788",
                      "name": "DR P2",
                      "liveDescription": "P2 er den inspirerende musikkanal for alle der holder af klassisk. Døgnet rundt med den bedste musik, udblik og passionerede værter.",
                      "beoradio": [
                        "stationId": "3666300007607788"
                      ],
                      "image": [
                        [
                          "url": "http://static.airable.io/88/23/496262.png",
                          "size": "large",
                          "mediatype": "image/png"
                        ],
                        [
                          "url": "http://static.airable.io/66/53/876129.png",
                          "size": "medium",
                          "mediatype": "image/png"
                        ],
                        [
                          "url": "http://static.airable.io/78/28/481228.png",
                          "size": "small",
                          "mediatype": "image/png"
                        ]
                      ]
                    ],
                    "_capabilities": [
                      "editable": [
                        "number"
                      ]
                    ],
                    "_links": [
                      "/relation/delete": [
                        "href": "./3666300007607788"
                      ],
                      "self": [
                        "href": "./3666300007607788"
                      ]
                    ]
                  ],
                  [
                    "id": "8779112938791514",
                    "number": 2,
                    "station": [
                      "id": "8779112938791514",
                      "name": "DR P3",
                      "liveDescription": "Det du hører, er du selv",
                      "beoradio": [
                        "stationId": "8779112938791514"
                      ],
                      "image": [
                        [
                          "url": "http://static.airable.io/18/61/194909.png",
                          "size": "large",
                          "mediatype": "image/png"
                        ],
                        [
                          "url": "http://static.airable.io/99/64/130945.png",
                          "size": "medium",
                          "mediatype": "image/png"
                        ],
                        [
                          "url": "http://static.airable.io/18/37/532943.png",
                          "size": "small",
                          "mediatype": "image/png"
                        ]
                      ]
                    ],
                    "_capabilities": [
                      "editable": [
                        "number"
                      ]
                    ],
                    "_links": [
                      "/relation/delete": [
                        "href": "./8779112938791514"
                      ],
                      "self": [
                        "href": "./8779112938791514"
                      ]
                    ]
                  ]
                ],
                "_links": [
                  "/relation/modify": [
                    "href": "."
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
