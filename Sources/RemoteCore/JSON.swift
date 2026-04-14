import Foundation

class JSON {
    private let value: Any

    public init(from: Any) {
        self.value = from
    }

    static func from(input: Data?) -> JSON? {
        if let data = input, let object = try? JSONSerialization.jsonObject(with: data) {
            return JSON(from: object)
        } else {
            return nil
        }
    }

    static func from(input: String) -> JSON? {
        return from(input: Data(input.utf8))
    }

    func serialize() -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func getAny() -> Any {
        return value
    }

    func getAny(at path: [String]) -> Any? {
        guard let root = value as? [String: Any] else {
            return nil
        }

        var current: Any = root
        for key in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[key] else {
                return nil
            }
            current = next
        }

        return current
    }

    func getString(at path: [String]) -> String? {
        return getAny(at: path) as? String
    }

    func getBool(at path: [String]) -> Bool? {
        return getAny(at: path) as? Bool
    }

    func getInt(at path: [String]) -> Int? {
        return getAny(at: path) as? Int
    }

}
