import XCTest
import class Foundation.Bundle
import RemoteCore

final class NotificationBridgeTests: XCTestCase {
    func testSourceNotification() throws {
        let data: Data =
            """
            {"notification":{"timestamp":"2019-12-02T22:18:09.440820","type":"SOURCE","kind":"source","data":{"primary":"spotify:1234.1234567.12345678@products.bang-olufsen.com","primaryJid":"1234.1234567.12345678@products.bang-olufsen.com","primaryExperience":{"source":{"id":"spotify:1234.1234567.12345678@products.bang-olufsen.com","friendlyName":"Spotify","sourceType":{"type":"SPOTIFY"},"category":"MUSIC","inUse":true,"profile":"","linkable":false,"recommendedIrMapping":[{"format":0,"unit":0,"command":146},{"format":11,"unit":0,"command":150}],"contentProtection":{"schemeList":["PROPRIETARY"]},"embeddedBinary":{"schemeList":["SPOTIFY_EMBEDDED_SDK"]},"product":{"jid":"1234.1234567.12345678@products.bang-olufsen.com","friendlyName":"Beoplay Device"}},"listener":["1234.1234567.12345678@products.bang-olufsen.com"],"lastUsed":"2019-12-02T22:18:07.692000","state":"play","_capabilities":{"supportedNotifications":[{"type":"SOURCE","kind":"source"},{"type":"SOURCE_EXPERIENCE_CHANGED","kind":"source"},{"type":"PLAY_QUEUE_CHANGED","kind":"playing"},{"type":"NOW_PLAYING_ENDED","kind":"playing"},{"type":"STREAMING_STATUS","kind":"streaming"},{"type":"PROGRESS_INFORMATION","kind":"playing"},{"type":"NOW_PLAYING_STORED_MUSIC","kind":"playing"}]}}}}}
            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onSourceChange, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testSourceNotificationWithLinebreaks() throws {
        let data: Data =
            """
                {"notification":{"timestamp":"2019-12-02T22:18:09.440820","type":"SOURCE","kind":"source","data":{"primary":"spotify:1234.1234567.12345678@products.bang-olufsen.com",
            "primaryJid":"1234.1234567.12345678@products.bang-olufsen.com","primaryExperience":{"source":{"id":"spotify:1234.1234567.12345678@products.bang-olufsen.com","friendlyName":"Spotify","sourceType":{"type":"SPOTIFY"},"category":"MUSIC","inUse":true,"profile":"","linkable":false,"recommendedIrMapping":[{"format":0,"unit":0,"command":146},{"format":11,"unit":0,"command":150}],"contentProtection":{"schemeList":["PROPRIETARY"]},"embeddedBinary":{"schemeList":["SPOTIFY_EMBEDDED_SDK"]},"product":{"jid":"1234.1234567.12345678@products.bang-olufsen.com","friendlyName":"Beoplay Device"}},"listener":["1234.1234567.12345678@products.bang-olufsen.com"],"lastUsed":"2019-12-02T22:18:07.692000","state":"play","_capabilities":{"supportedNotifications":[{"type":"SOURCE","kind":"source"},{"type":"SOURCE_EXPERIENCE_CHANGED","kind":"source"},{"type":"PLAY_QUEUE_CHANGED","kind":"playing"},{"type":"NOW_PLAYING_ENDED","kind":"playing"},{"type":"STREAMING_STATUS","kind":"streaming"},{"type":"PROGRESS_INFORMATION","kind":"playing"},{"type":"NOW_PLAYING_STORED_MUSIC","kind":"playing"}]}}}}}
            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onSourceChange, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testSourceNotificationWithLinebreakAfterCurly() throws {
        let data: Data =
            """
            {"notification":{"timestamp":"2019-12-02T22:18:09.440820","type":"SOURCE","kind":"source","data":{"primary":"spotify:1234.1234567.12345678@products.bang-olufsen.com","primaryJid":"1234.1234567.12345678@products.bang-olufsen.com","primaryExperience":{"source":{"id":"spotify:1234.1234567.12345678@products.bang-olufsen.com","friendlyName":"Spotify","sourceType":{"type":"SPOTIFY"},"category":"MUSIC","inUse":true,"profile":"","linkable":false,"recommendedIrMapping":[{"format":0,"unit":0,"command":146},{"format":11,"unit":0,"command":150}],"contentProtection":{"schemeList":["PROPRIETARY"]},"embeddedBinary":{"schemeList":["SPOTIFY_EMBEDDED_SDK"]},"product":{"jid":"1234.1234567.12345678@products.bang-olufsen.com","friendlyName":"Beoplay Device"}},"listener":["1234.1234567.12345678@products.bang-olufsen.com"],"lastUsed":"2019-12-02T22:18:07.692000","state":"play","_capabilities":{"supportedNotifications":[{"type":"SOURCE","kind":"source"},{"type":"SOURCE_EXPERIENCE_CHANGED","kind":"source"},{"type":"PLAY_QUEUE_CHANGED","kind":"playing"},{"type":"NOW_PLAYING_ENDED","kind":"playing"},{"type":"STREAMING_STATUS","kind":"streaming"},{"type":"PROGRESS_INFORMATION","kind":"playing"},{"type":"NOW_PLAYING_STORED_MUSIC","kind":"playing"}

                ]}}}}}
            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onSourceChange, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testRadioNotification() throws {
        let data: Data =
            """
                {"notification":{"timestamp":"2019-12-02T23:35:54.464106","type":"NOW_PLAYING_NET_RADIO","kind":"playing","data":{"name":"DR P4","genre":"","country":"","languages":"","image":[{"url":"http://cdn-profiles.tunein.com/s37309/images/logog.png","size":"large","mediatype":"image/png"}],"liveDescription":"Just an illusion - Imagination","stationId":"s37309","playQueueItemId":"plid-640"}}}
            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onNowPlayingRadio, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testStoredMusicNotification() throws {
        let data: Data =
            """
            {"notification":{"timestamp":"2019-12-02T22:18:09.441606","type":"NOW_PLAYING_STORED_MUSIC","kind":"playing","data":{"name":"Places","duration":214,"trackImage":[{"url":"https://i.scdn.co/image/ab67616d0000b273fb8b2c04222171f2c970d6ac","size":"large","mediatype":"image/jpg"}],"artist":"The Blaze","artistImage":[],"album":"Dancehall","albumImage":[{"url":"https://i.scdn.co/image/ab67616d0000b273fb8b2c04222171f2c970d6ac","size":"large","mediatype":"image/jpg"}],"genre":"","playQueueItemId":"spotify:track:6mW2IiQDrp66AUjCsRu6Kg"}}}

            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onNowPlayingStoredMusic, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testProgressNotification() throws {
        let data: Data =
            """
                {"notification":{"timestamp":"2019-12-02T22:18:09.441855","type":"PROGRESS_INFORMATION","kind":"playing","data":{"state":"play","position":98,"totalDuration":214,"seekSupported":true,"playQueueItemId":"spotify:track:6mW2IiQDrp66AUjCsRu6Kg"}}}
            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onProgress, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testVolumeNotification() throws {
        let data: Data =
            """
                {"notification":{"timestamp":"2019-12-02T22:18:09.442015","type":"VOLUME","kind":"renderer","data":{"speaker":{"level":9,"muted":false,"range":{"minimum":0,"maximum":90}}}}}
            """.data(using: .utf8)!

        expectation(forNotification: Notification.Name.onVolumeChange, object: nil)
        NotificationBridge().process(data)
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testConnectionNotification() throws {
        expectation(forNotification: Notification.Name.onConnectionChange, object: nil)
        NotificationBridge().update(state: NotificationSession.ConnectionState.connecting)
        waitForExpectations(timeout: 0.1, handler: nil)
    }
}
