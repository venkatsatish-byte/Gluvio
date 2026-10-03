import Foundation
import GlucoseCore
import Security

/// Keeps the parent PIN's salted hash in the Keychain (this device only, never
/// synced). The PIN itself is never stored.
struct PINStore {
    private let service = "app.gluvio.parent-pin"
    let account: String

    var hasPIN: Bool { load() != nil }

    func verify(_ pin: String) -> Bool {
        guard let record = load() else { return false }
        return PINHasher.verify(pin, against: record)
    }

    @discardableResult
    func set(_ pin: String) -> Bool {
        guard PINHasher.isValid(pin), let data = try? JSONEncoder().encode(PINHasher.makeRecord(pin: pin)) else { return false }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func load() -> PINRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(PINRecord.self, from: data)
    }
}
