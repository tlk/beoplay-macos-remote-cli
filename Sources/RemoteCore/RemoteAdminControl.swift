import Foundation
import SwiftyJSON

public class RemoteAdminControl {
    private var endpoint = URLComponents()

    public init() {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
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

    public func setEndpoint(host: String, port: Int) {
        self.endpoint.host = host
        self.endpoint.port = port
        self.endpoint.scheme = "http"
    }

    public func clearEndpoint() {
        self.endpoint.host = nil
        self.endpoint.port = nil
    }

    public func getEnabledControlledSourceIds(_ completion: @escaping ([String]) -> ()) {
        func completionData(data: Data?) {
            var sourceIds = [String]()

            guard let jsonData = data, jsonData.count > 0 else {
                completion(sourceIds)
                return
            }

            let json = JSON(data: jsonData)

            guard let list = json[0]["controlledSources"]["controlledSources"].array else {
                completion(sourceIds)
                return
            }

            for source in list {
                if source["enabled"].boolValue, let id = source["sourceId"].string {
                    sourceIds.append(id)
                }
            }
            completion(sourceIds)
        }

        request(method: "GET", path: "/api/getData", query: "path=settings:/beo/sources/controlledSources&roles=value", completionData: completionData)
    }

}
