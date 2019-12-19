import Foundation
import Embassy
import Ambassador
import RemoteCore

public class DeviceEmulator {
    let debug = false
    let productType = "CA16"
    let serialNumber = "28000000"
    let typeNumber = "2714"
    let itemNumber = "1200000"
    let jid = "1234.1234567.12345678@products.bang-olufsen.com"
    let macAddress = "AC:89:95:B0:B0:B0"
    let anonymousProductId = "BOEMULATOR1BOEMULATOR2BOEMULATOR"

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
        ns?.includesPeerToPeer = true

        // https://stackoverflow.com/a/49611595/936466
        let records = [
            "assoc": "".data(using: .utf8)!,
            "item": itemNumber.data(using: .utf8)!,
            "jid": jid.data(using: .utf8)!,
            "name": getName().data(using: .utf8)!,
            "productType": productType.data(using: .utf8)!,
            "services": "BeoInput,BeoNotify,BeoZone,BeoDevice,BeoContent,BeoHome,BeoSecurity".data(using: .utf8)!,
            "type": typeNumber.data(using: .utf8)!
        ]

        ns?.setTXTRecord(NetService.data(fromTXTRecord: records))
        ns?.publish()

        let ns_settings = NetService(domain: "local.", type: "_beo_settings._tcp.", name: name, port: Int32(port))
        ns_settings.includesPeerToPeer = true
        ns_settings.setTXTRecord(NetService.data(fromTXTRecord: ["DEVICE_TYPE": "CA16".data(using: .utf8)!]))
        ns_settings.publish()


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

    func addRoutes() {
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
                    "jid": self.jid,
                    "sourceType": ["type": "TUNEIN"],
                    "category": "RADIO",
                    "friendlyName": "TuneIn",
                    "borrowed": false,
                    "product": [
                        "jid": self.jid,
                        "friendlyName": self.getName()
                    ]
                ]
            ],
            [
                "linein:1234.1234567.12345678@products.bang-olufsen.com",
                [
                    "id": "linein:1234.1234567.12345678@products.bang-olufsen.com",
                    "jid": self.jid,
                    "sourceType": ["type": "LINE IN"],
                    "category": "MUSIC",
                    "friendlyName": "Line-In",
                    "borrowed": false,
                    "product": [
                        "jid": self.jid,
                        "friendlyName": self.getName()
                    ]
                ]
            ],
            [
                "bluetooth:1234.1234567.12345678@products.bang-olufsen.com",
                [
                    "id": "bluetooth:1234.1234567.12345678@products.bang-olufsen.com",
                    "jid": self.jid,
                    "sourceType": ["type": "BLUETOOTH"],
                    "category": "MUSIC",
                    "friendlyName": "Bluetooth",
                    "borrowed": false,
                    "product": [
                        "jid": self.jid,
                        "friendlyName": self.getName()
                    ]
                ]
            ],
            [
                "alarm:1234.1234567.12345678@products.bang-olufsen.com",
                [
                    "id": "alarm:1234.1234567.12345678@products.bang-olufsen.com",
                    "jid": self.jid,
                    "sourceType": ["type": "ALARM"],
                    "category": "ALARM",
                    "friendlyName": "Alarm",
                    "borrowed": false,
                    "product": [
                        "jid": self.jid,
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

        router["/BeoDevice/"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "beoDevice": [
                    "productId": [
                        "productType": self.productType,
                        "typeNumber": self.typeNumber,
                        "serialNumber": self.serialNumber,
                        "itemNumber": self.itemNumber
                    ],
                    "productFamily": "play",
                    "productFriendlyName": [
                        "productFriendlyName": self.getName(),
                        "_capabilities": [
                            "editable": [
                                "productFriendlyName"
                            ]
                        ],
                        "_links": [
                            "/relation/modify": [
                                "href": "./productFriendlyName"
                            ]
                        ]
                    ],
                    "productImage": [],
                    "software": [
                        "version": "1.21.34088.134789577",
                        "softwareUpdateProductTypeId": 59
                    ],
                    "hardware": [
                        "version": self.productType,
                        "type": self.typeNumber,
                        "item": self.itemNumber,
                        "serial": self.serialNumber,
                        "bom": "PVT",
                        "pcb": "unknown",
                        "variant": "unknown",
                        "mac": self.macAddress
                    ],
                    "profiles": [
                        [
                            "name": "networkSettingsProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./networkSettings/"
                                ]
                            ]
                        ],
                        [
                            "name": "modulesInformationProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./modulesInformation/"
                                ]
                            ]
                        ],
                        [
                            "name": "credentialProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./credentials/"
                                ]
                            ]
                        ],
                        [
                            "name": "powerManagementProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./powerManagement/"
                                ]
                            ]
                        ],
                        [
                            "name": "associationProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./association/"
                                ]
                            ]
                        ],
                        [
                            "name": "lineInSettingsProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./lineInSettings/"
                                ]
                            ]
                        ],
                        [
                            "name": "factoryResetProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./factoryReset/"
                                ]
                            ]
                        ],
                        [
                            "name": "regionalSettingsProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./regionalSettings/"
                                ]
                            ]
                        ],
                        [
                            "name": "logReportingProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./logReporting/"
                                ]
                            ]
                        ],
                        [
                            "name": "softwareUpdateProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./softwareUpdate/"
                                ]
                            ]
                        ],
                        [
                            "name": "termsAndConditionsProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./termsAndConditions/"
                                ]
                            ]
                        ],
                        [
                            "name": "bluetoothSettingsProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./bluetoothSettings/"
                                ]
                            ]
                        ],
                        [
                            "name": "remoteControlPairingProfile",
                            "version": 1,
                            "_links": [
                                "self": [
                                    "href": "./remoteControlPairing/"
                                ]
                            ]
                        ]
                    ],
                    "anonymousProductId": self.anonymousProductId
                ]
            ]
        }))

        router["/BeoDevice/softwareupdate/"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "profile": [
                    "name": "softwareUpdateProfile",
                    "version": 1,
                    "_links": [
                        "self": [
                            "href": "./"
                        ]
                    ],
                    "softwareUpdate": [
                        "mode": [
                            "mode": "manual",
                            "_capabilities": [
                                "editable": [
                                    "mode"
                                ],
                                "value": [
                                    "mode": [
                                        "manual",
                                        "automatic"
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/modify": [
                                    "href": "./mode"
                                ]
                            ]
                        ],
                        "state": [
                            "state": "idle",
                            "_capabilities": [
                                "editable": [
                                    "state"
                                ],
                                "value": [
                                    "state": [
                                        "checkingForUpdates"
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/modify": [
                                    "href": "./state"
                                ]
                            ]
                        ],
                        "latestUpdate": "2019-11-21T13:37:38",
                        "latestCheck": "2019-12-14T12:00:23.687000",
                        "version": "1.21.34088.134789577",
                        "releaseDescription": [
                            "short": "",
                            "long": ""
                        ]
                    ]
                ]
            ]
        }))

        // Ignore PUT data
        router["/BeoDevice/softwareupdate/state"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "profile": [
                    "name": "softwareUpdateProfile",
                    "version": 1,
                    "_links": [
                        "self": [
                            "href": "./"
                        ]
                    ],
                    "softwareUpdate": [
                        "mode": [
                            "mode": "manual",
                            "_capabilities": [
                                "editable": [
                                    "mode"
                                ],
                                "value": [
                                    "mode": [
                                        "manual",
                                        "automatic"
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/modify": [
                                    "href": "./mode"
                                ]
                            ]
                        ],
                        "state": [
                            "state": "checkingForUpdates"
                        ],
                        "latestUpdate": "2019-11-21T13:37:38",
                        "latestCheck": "2019-12-14T12:00:23.687000",
                        "version": "1.21.34088.134789577",
                        "releaseDescription": [
                            "short": "",
                            "long": ""
                        ]
                    ]
                ]
            ]
        }))

        router["/BeoDevice/termsAndConditions/"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "profile": [
                    "name": "termsAndConditionsProfile",
                    "version": 1,
                    "_links": [
                        "self": [
                            "href": "./"
                        ]
                    ],
                    "termsAndConditions": [
                        "acknowledgement": [
                            "state": "accepted",
                            "_capabilities": [
                                "editable": [
                                    "state"
                                ],
                                "value": [
                                    "state": [
                                        "accepted",
                                        "declined"
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/modify": [
                                    "href": "./acknowledgement"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        }))

        router["/BeoDevice/credentials/"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "profile": [
                    "name": "credentialProfile",
                    "version": 1,
                    "_links": [
                        "self": [
                            "href": "./"
                        ]
                    ],
                    "credential": [
                        "deezer": [
                            "account": [
                                [
                                    "id": "deezer_account",
                                    "service": "deezer",
                                    "username": "foo@bar.xyz",
                                    "passphrase": "********",
                                    "loginType": "standard",
                                    "token": "aaaabaaacaaadaaaeaaafaaagaaahaaaiaaajaaakaaalaaama",
                                    "active": true,
                                    "_capabilities": [
                                        "editable": [
                                            "username",
                                            "passphrase"
                                        ]
                                    ],
                                    "_links": [
                                        "/relation/delete": [
                                            "href": "./credential/deezer_account"
                                        ],
                                        "/relation/modify": [
                                            "href": "./credential"
                                        ]
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/create": [
                                    "href": "./credential"
                                ],
                                "self": [
                                    "href": "./credential?search=service=%22deezer%22"
                                ]
                            ]
                        ],
                        "spotify": [
                            "account": [
                                [
                                    "id": "spotify_account",
                                    "service": "spotify",
                                    "username": "999999999",
                                    "passphrase": "",
                                    "loginType": "standard",
                                    "active": true,
                                    "_links": [
                                        "/relation/delete": [
                                            "href": "./credential/spotify_account"
                                        ]
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/create": [
                                    "href": "./credential"
                                ],
                                "self": [
                                    "href": "./credential?search=service=%22spotify%22"
                                ]
                            ]
                        ],
                        "tuneIn": [
                            "account": [
                                [
                                    "id": "tunein_account",
                                    "service": "tuneIn",
                                    "username": "aaaabaaacaaadaaaeaaa",
                                    "passphrase": "********",
                                    "loginType": "standard",
                                    "token": "aaaabaaacaaadaaaeaaafaaagaaahaaa",
                                    "active": true,
                                    "_capabilities": [
                                        "editable": [
                                            "username",
                                            "passphrase"
                                        ]
                                    ],
                                    "_links": [
                                        "/relation/delete": [
                                            "href": "./credential/tunein_account"
                                        ],
                                        "/relation/modify": [
                                            "href": "./credential"
                                        ]
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/create": [
                                    "href": "./credential"
                                ],
                                "self": [
                                    "href": "./credential?search=service=%22tuneIn%22"
                                ]
                            ]
                        ],
                        "beoCloud": [
                            "account": [
                                [
                                    "id": "beoCloud_account",
                                    "service": "beoCloud",
                                    "username": "https://cloud.bang-olufsen.com/api/v1",
                                    "passphrase": "",
                                    "loginType": "standard",
                                    "active": true,
                                    "secureToken": "********",
                                    "secureTokenValid": true,
                                    "_capabilities": [
                                        "editable": [
                                            "username",
                                            "secureToken"
                                        ]
                                    ],
                                    "_links": [
                                        "/relation/delete": [
                                            "href": "./credential/beoCloud_account"
                                        ],
                                        "/relation/modify": [
                                            "href": "./credential"
                                        ]
                                    ]
                                ]
                            ],
                            "_links": [
                                "/relation/create": [
                                    "href": "./credential"
                                ],
                                "self": [
                                    "href": "./credential?search=service=%22beoCloud%22"
                                ]
                            ]
                        ],
                        "_links": [
                            "self": [
                                "href": "./credential"
                            ]
                        ]
                    ],
                    "credentialTypes": [
                        "deezer",
                        "spotify",
                        "tuneIn",
                        "beoCloud"
                    ]
                ]
            ]
        }))

        router["/BeoHome/trigger/"] = DelayResponse(JSONResponse(handler: { _ -> Any in
            return [
                "profile": [
                    "name": "triggerProfile",
                    "version": 1,
                    "_links": [
                        "self": [
                            "href": "./"
                        ]
                    ],
                    "trigger": [
                        "timerList": [
                            "_links": [
                                "self": [
                                    "href": "./timerList"
                                ]
                            ]
                        ],
                        "triggerSequenceList": [
                            "_links": [
                                "self": [
                                    "href": "./triggerSequenceList"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
//            [
//                "timerList": [
//                    "timer": [],
//                    "_links": [
//                        "/relation/create": [
//                            "href": "./"
//                        ],
//                        "self": [
//                            "href": "./"
//                        ]
//                    ]
//                ]
//            ]
//
//            [
//                "ToneTouch": [
//                    "Gx1": 0.28921619057655334,
//                    "Gx2": -0.11130693554878235,
//                    "Gy1": 0.13820566236972809,
//                    "Gy2": -0.084648005664348602,
//                    "Gz": 0.20949999988079071,
//                    "k5": -0.89125710725784302,
//                    "k6": -0.97312581539154053,
//                    "enabled": true
//                ]
//            ]
        }))

        router["/hello-world"] = DataResponse(statusCode: 200, contentType: "text/html; charset=UTF-8") { environ -> Data in
            return Data("<h1>beoplay-cli emulator: \(self.getName())</h1>".utf8)
        }
    }
}
