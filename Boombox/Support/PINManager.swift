import Foundation
import Security

/// Stores the 4-digit parent PIN in the Keychain and enforces the
/// five-attempts-then-one-minute lockout. There is no PIN recovery in v1.
enum PINManager {
    private static let service = "com.boombox.parentpin"
    private static let account = "parentPIN"
    private static let attemptsKey = "boombox.pin.failedAttempts"
    private static let lockoutKey = "boombox.pin.lockoutUntil"

    static let maxAttempts = 5
    static let lockoutSeconds: TimeInterval = 60

    // MARK: - Keychain

    static var hasPIN: Bool { loadPIN() != nil }

    static func savePIN(_ pin: String) {
        deletePIN()
        guard let data = pin.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
        resetAttempts()
    }

    static func loadPIN() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePIN() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Verification and lockout

    /// Seconds until the pad unlocks again, or nil when not locked out.
    static var lockoutRemaining: TimeInterval? {
        let until = UserDefaults.standard.double(forKey: lockoutKey)
        guard until > 0 else { return nil }
        let remaining = until - Date.now.timeIntervalSince1970
        return remaining > 0 ? remaining : nil
    }

    static func verify(_ pin: String) -> Bool {
        guard lockoutRemaining == nil else { return false }
        guard let stored = loadPIN() else { return false }
        if pin == stored {
            resetAttempts()
            return true
        }
        let attempts = UserDefaults.standard.integer(forKey: attemptsKey) + 1
        if attempts >= maxAttempts {
            UserDefaults.standard.set(
                Date.now.timeIntervalSince1970 + lockoutSeconds, forKey: lockoutKey)
            resetAttempts()
        } else {
            UserDefaults.standard.set(attempts, forKey: attemptsKey)
        }
        return false
    }

    private static func resetAttempts() {
        UserDefaults.standard.removeObject(forKey: attemptsKey)
    }
}
