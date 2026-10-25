import Foundation
import Testing
import ReaderSync

struct KeychainCredentialStoreTests {
    enum Operation: String, CaseIterable, Sendable {
        case read, save, remove
    }

    @Test("Cancelled credential operations fail before accessing Keychain", arguments: Operation.allCases)
    func cancelledCredentialOperationsFailBeforeAccessingKeychain(operation: Operation) async throws {
        let store = KeychainCredentialStore(service: "eu.mpwg.reader.tests.\(UUID().uuidString)")
        let accountID = UUID()
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            switch operation {
            case .read:
                _ = try await store.password(accountID: accountID)
            case .save:
                try await store.savePassword("isolated-test-value", accountID: accountID)
            case .remove:
                try await store.removePassword(accountID: accountID)
            }
        }
        await #expect(throws: CancellationError.self) { try await request.value }
        // Clean up only this unique fixture namespace, including if a regression permitted a save.
        try await store.removePassword(accountID: accountID)
    }
}
