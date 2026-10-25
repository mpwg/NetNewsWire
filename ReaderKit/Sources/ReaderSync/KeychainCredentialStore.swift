import Foundation
import Security
import ReaderDomain

/// Blocking Security calls execute on this actor, outside the UI actor. Credentials remain device-local.
public actor KeychainCredentialStore: CredentialStore {
    private let service: String
    private let access: any KeychainAccess

    public init(service: String = "eu.mpwg.reader.credentials") {
        self.service = service
        self.access = SystemKeychainAccess()
    }

    init(service: String, access: any KeychainAccess) {
        self.service = service
        self.access = access
    }

    public func password(accountID: UUID) throws -> String? {
        try Task.checkCancellation()
        var query = baseQuery(accountID)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        let (status, data) = access.copyMatching(query)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let data, let password = String(data: data, encoding: .utf8) else { throw ReaderError.invalidResponse }
        return password
    }

    public func savePassword(_ password: String, accountID: UUID) throws {
        try Task.checkCancellation()
        let query = baseQuery(accountID)
        let update: [CFString: Any] = [kSecValueData: Data(password.utf8)]
        let status = access.update(query, attributes: update)
        if status == errSecItemNotFound {
            try Task.checkCancellation()
            var addition = query
            addition[kSecValueData] = update[kSecValueData]
            addition[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = access.add(addition)
            if addStatus == errSecDuplicateItem {
                try Task.checkCancellation()
                try check(access.update(query, attributes: update))
            } else { try check(addStatus) }
        } else { try check(status) }
    }

    public func removePassword(accountID: UUID) throws {
        try Task.checkCancellation()
        let status = access.remove(baseQuery(accountID))
        if status != errSecItemNotFound { try check(status) }
    }

    private func baseQuery(_ accountID: UUID) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: accountID.uuidString, kSecAttrSynchronizable: false]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw ReaderError.unavailable(String(localized: "Keychain access failed (\(status)).", bundle: #bundle))
        }
    }
}

/// Synchronous adapter keeps OS calls on the owning actor and permits isolated error-path verification.
protocol KeychainAccess: Sendable {
    func copyMatching(_ query: [CFString: Any]) -> (OSStatus, Data?)
    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus
    func add(_ query: [CFString: Any]) -> OSStatus
    func remove(_ query: [CFString: Any]) -> OSStatus
}

private struct SystemKeychainAccess: KeychainAccess {
    func copyMatching(_ query: [CFString: Any]) -> (OSStatus, Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func add(_ query: [CFString: Any]) -> OSStatus { SecItemAdd(query as CFDictionary, nil) }
    func remove(_ query: [CFString: Any]) -> OSStatus { SecItemDelete(query as CFDictionary) }
}
