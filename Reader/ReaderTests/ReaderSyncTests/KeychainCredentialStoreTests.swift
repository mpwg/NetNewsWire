import Foundation
import Dispatch
import Security
import Synchronization
import Testing
import ReaderDomain
@testable import ReaderSync

struct KeychainCredentialStoreTests {
    enum Operation: String, CaseIterable, Sendable {
        case read, save, remove

        fileprivate var firstCall: StubKeychainAccess.Call {
            switch self {
            case .read: .read
            case .save: .update
            case .remove: .remove
            }
        }
    }

    @Test("Cancelled credential operations make no OS calls", arguments: Operation.allCases)
    func cancelledCredentialOperationsFailBeforeAccessingKeychain(operation: Operation) async throws {
        let access = StubKeychainAccess()
        let store = KeychainCredentialStore(service: UUID().uuidString, access: access)
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await Self.perform(operation, store: store)
        }
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(access.calls.isEmpty)
    }

    @Test("Credential OS errors preserve status and fail without retrying",
          arguments: Operation.allCases, [errSecNotAvailable, errSecInteractionNotAllowed, errSecAuthFailed])
    func credentialOSErrorsPreserveStatusAndDoNotRetry(operation: Operation, status: OSStatus) async {
        let access = StubKeychainAccess(defaultStatus: status)
        let store = KeychainCredentialStore(service: UUID().uuidString, access: access)
        await #expect {
            try await Self.perform(operation, store: store)
        } throws: { error in
            guard let error = error as? ReaderError, case .unavailable(let message) = error else { return false }
            return message.filter { $0.isNumber || $0 == "-" } == String(status)
        }
        #expect(access.calls == [operation.firstCall])
    }

    @Test("Cancellation after an OS write prevents the next recovery call", arguments: [1, 2])
    func cancellationPreventsFurtherWriteRecoveryCalls(blockingCall: Int) async throws {
        let gate = BlockingKeychainGate()
        let access = StubKeychainAccess(statuses: [errSecItemNotFound, errSecDuplicateItem, errSecSuccess],
                                        gate: gate, blockingCall: blockingCall)
        let store = KeychainCredentialStore(service: UUID().uuidString, access: access)
        let request = Task { try await store.savePassword("isolated-test-value", accountID: UUID()) }
        defer { request.cancel(); gate.release() }
        try await gate.waitUntilEntered()
        request.cancel()
        gate.release()
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(access.calls == Array([.update, .add].prefix(blockingCall)))
        #expect(!gate.timedOut)
    }

    @MainActor
    @Test("An in-progress Security call leaves MainActor free", .timeLimit(.minutes(1)))
    func blockedSecurityCallsLeaveMainActorResponsive() async throws {
        let gate = BlockingKeychainGate()
        let access = StubKeychainAccess(gate: gate, blockingCall: 1)
        let store = KeychainCredentialStore(service: UUID().uuidString, access: access)
        let request = Task { try await store.password(accountID: UUID()) }
        defer { request.cancel(); gate.release() }
        try await gate.waitUntilEntered()
        try #require(gate.isWaiting, "MainActor must run before the bounded OS-call simulation returns.")
        MainActor.assertIsolated()
        gate.release()
        #expect(try await request.value == "isolated-test-value")
        #expect(!gate.timedOut)
        #expect(access.calls == [.read])
    }

    @Test("Concurrent item creation recovers without changing device-local protection")
    func concurrentCreationPreservesDeviceLocalProtection() async throws {
        let access = StubKeychainAccess(statuses: [errSecItemNotFound, errSecDuplicateItem, errSecSuccess])
        let service = UUID().uuidString
        let accountID = UUID()
        let store = KeychainCredentialStore(service: service, access: access)
        try await store.savePassword("isolated-test-value", accountID: accountID)
        #expect(access.calls == [.update, .add, .update])
        #expect(access.lastService == service)
        #expect(access.lastAccount == accountID.uuidString)
        #expect(access.synchronizable == false)
        #expect(access.addedAccessibility == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("Ephemeral credentials are isolated by account and store lifetime")
    func ephemeralCredentialsStayInTheirStore() async throws {
        let store = EphemeralCredentialStore()
        let secondStore = EphemeralCredentialStore()
        let first = UUID()
        let second = UUID()
        try await store.savePassword("first-value", accountID: first)
        try await store.savePassword("second-value", accountID: second)
        #expect(try await store.password(accountID: first) == "first-value")
        #expect(try await store.password(accountID: second) == "second-value")
        #expect(try await secondStore.password(accountID: first) == nil)
        try await store.savePassword("replacement", accountID: first)
        try await store.removePassword(accountID: second)
        #expect(try await store.password(accountID: first) == "replacement")
        #expect(try await store.password(accountID: second) == nil)
    }

    @Test("Cancelled ephemeral credential operations leave stored values unchanged", arguments: Operation.allCases)
    func cancelledEphemeralCredentialsDoNotMutate(operation: Operation) async throws {
        let store = EphemeralCredentialStore()
        let account = UUID()
        try await store.savePassword("original", accountID: account)
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            switch operation {
            case .read: _ = try await store.password(accountID: account)
            case .save: try await store.savePassword("replacement", accountID: account)
            case .remove: try await store.removePassword(accountID: account)
            }
        }
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(try await store.password(accountID: account) == "original")
    }

    private static func perform(_ operation: Operation, store: KeychainCredentialStore) async throws {
        switch operation {
        case .read: _ = try await store.password(accountID: UUID())
        case .save: try await store.savePassword("isolated-test-value", accountID: UUID())
        case .remove: try await store.removePassword(accountID: UUID())
        }
    }
}

nonisolated private final class StubKeychainAccess: KeychainAccess {
    enum Call: Sendable, Equatable { case read, update, add, remove }
    private struct State {
        var statuses: [OSStatus]
        var calls: [Call] = []
        var service: String?
        var account: String?
        var synchronizable: Bool?
        var accessibility: String?
    }
    private let state: Mutex<State>
    private let defaultStatus: OSStatus
    private let gate: BlockingKeychainGate?
    private let blockingCall: Int

    init(statuses: [OSStatus] = [], defaultStatus: OSStatus = errSecSuccess,
         gate: BlockingKeychainGate? = nil, blockingCall: Int = 0) {
        state = Mutex(State(statuses: statuses))
        self.defaultStatus = defaultStatus
        self.gate = gate
        self.blockingCall = blockingCall
    }

    var calls: [Call] { state.withLock { $0.calls } }
    var lastService: String? { state.withLock { $0.service } }
    var lastAccount: String? { state.withLock { $0.account } }
    var synchronizable: Bool? { state.withLock { $0.synchronizable } }
    var addedAccessibility: String? { state.withLock { $0.accessibility } }

    func copyMatching(_ query: [CFString: Any]) -> (OSStatus, Data?) {
        (reply(.read, query: query), Data("isolated-test-value".utf8))
    }
    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus { reply(.update, query: query) }
    func add(_ query: [CFString: Any]) -> OSStatus { reply(.add, query: query) }
    func remove(_ query: [CFString: Any]) -> OSStatus { reply(.remove, query: query) }

    private func reply(_ call: Call, query: [CFString: Any]) -> OSStatus {
        let count = state.withLock {
            $0.calls.append(call)
            $0.service = query[kSecAttrService] as? String
            $0.account = query[kSecAttrAccount] as? String
            $0.synchronizable = query[kSecAttrSynchronizable] as? Bool
            if call == .add { $0.accessibility = query[kSecAttrAccessible] as? String }
            return $0.calls.count
        }
        if count == blockingCall { gate?.pause() }
        return state.withLock { $0.statuses.isEmpty ? defaultStatus : $0.statuses.removeFirst() }
    }
}

/// Models a bounded synchronous OS call. The MainActor releases it while it is still blocked.
nonisolated private final class BlockingKeychainGate: Sendable {
    enum Failure: Error { case didNotEnter }
    private struct State { var entered = false; var waiting = false; var timedOut = false }
    private let state = Mutex(State())
    private let semaphore = DispatchSemaphore(value: 0)
    var isWaiting: Bool { state.withLock { $0.waiting } }
    var timedOut: Bool { state.withLock { $0.timedOut } }

    func pause() {
        state.withLock { $0.entered = true; $0.waiting = true }
        let result = semaphore.wait(timeout: .now() + 5)
        state.withLock { $0.waiting = false; $0.timedOut = result == .timedOut }
    }

    func release() { semaphore.signal() }

    func waitUntilEntered() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !state.withLock({ $0.entered }) {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw Failure.didNotEnter }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
