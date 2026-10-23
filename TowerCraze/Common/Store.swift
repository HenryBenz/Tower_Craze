import Foundation

/// Сохранения игры в UserDefaults. Все ключи получают префикс игры, поэтому Clear Data удаляет ровно данные этой игры.
final class Store {
    static let shared = Store()
    var prefix: String = "game."
    private let defaults = UserDefaults.standard

    private init() {}

    private func key(_ name: String) -> String { prefix + name }

    func int(_ name: String, _ fallback: Int = 0) -> Int {
        guard defaults.object(forKey: key(name)) != nil else { return fallback }
        return defaults.integer(forKey: key(name))
    }

    func setInt(_ name: String, _ value: Int) {
        defaults.set(value, forKey: key(name))
    }

    func bool(_ name: String) -> Bool {
        defaults.bool(forKey: key(name))
    }

    func setBool(_ name: String, _ value: Bool) {
        defaults.set(value, forKey: key(name))
    }

    func load<T: Codable>(_ name: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func save<T: Codable>(_ name: String, _ value: T?) {
        if let value = value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key(name))
        } else {
            defaults.removeObject(forKey: key(name))
        }
    }

    func remove(_ name: String) {
        defaults.removeObject(forKey: key(name))
    }

    /// Удаляет все сохранения этой игры.
    func clearAll() {
        let all = defaults.dictionaryRepresentation().keys
        for k in all where k.hasPrefix(prefix) {
            defaults.removeObject(forKey: k)
        }
        defaults.synchronize()
    }
}
