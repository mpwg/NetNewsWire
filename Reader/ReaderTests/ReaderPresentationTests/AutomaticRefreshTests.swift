import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderSync
@testable import ReaderUI

@MainActor
struct AutomaticRefreshTests {
    @Test("Callers join the held account job before debounce or a later forced refresh", .timeLimit(.minutes(1)),
          arguments: [false, true])
    func callersJoinActiveRefreshBeforeDebounce(forceJoiner: Bool) async throws {
        let fixture = try await RefreshFixture()
        let a = RefreshCompletion()
        let b = RefreshCompletion()
        let first = start(fixture.services, completion: a)
        defer { first.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        #expect(fixture.services.refreshWaiterCount == 1)
        let second = start(fixture.services, completion: b, force: forceJoiner)
        defer { second.cancel() }
        #expect(await waitUntil { fixture.services.refreshWaiterCount == 2 })
        #expect(await fixture.server.subscriptions == 1)
        #expect(a.outcome == nil)
        #expect(b.outcome == nil)
        #expect(fixture.services.revision == 0)
        await fixture.gate.open()
        await first.value
        await second.value
        #expect(a.outcome == .success)
        #expect(b.outcome == .success)
        #expect(fixture.services.refreshWaiterCount == 0)
        #expect(fixture.services.revision == 1)
        try await fixture.services.refreshIfNeeded()
        #expect(await fixture.server.subscriptions == 1)
        try await fixture.services.refreshIfNeeded(force: true)
        #expect(await fixture.server.subscriptions == 2)
        #expect(fixture.services.revision == 2)
    }

    enum CancelledCallers: CaseIterable, Sendable { case first, second, both }

    @Test("Cancelled windows stop waiting without cancelling the owned account job", .timeLimit(.minutes(1)),
          arguments: CancelledCallers.allCases)
    func cancelledCallersLeaveOwnedRefreshRunning(cancelled: CancelledCallers) async throws {
        let fixture = try await RefreshFixture()
        let a = RefreshCompletion()
        let b = RefreshCompletion()
        let first = start(fixture.services, completion: a)
        defer { first.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        let second = start(fixture.services, completion: b)
        defer { second.cancel() }
        #expect(await waitUntil { fixture.services.refreshWaiterCount == 2 })
        if cancelled != .second { first.cancel() }
        if cancelled != .first { second.cancel() }
        #expect(await waitUntil {
            (cancelled == .second || a.outcome != nil) && (cancelled == .first || b.outcome != nil)
        }, "Cancelled callers must finish while the shared HTTP response is still held.")
        #expect(fixture.services.refreshWaiterCount == (cancelled == .both ? 0 : 1))
        let newcomer = RefreshCompletion()
        let third: Task<Void, Never>?
        if cancelled == .both {
            third = start(fixture.services, completion: newcomer)
            #expect(await waitUntil { fixture.services.refreshWaiterCount == 1 })
        } else { third = nil }
        #expect(await fixture.server.subscriptions == 1)
        #expect(await fixture.server.cancellations == 0)
        #expect(fixture.services.revision == 0)
        await fixture.gate.open()
        await first.value
        await second.value
        await third?.value
        #expect(a.outcome == (cancelled == .second ? .success : .cancelled))
        #expect(b.outcome == (cancelled == .first ? .success : .cancelled))
        if cancelled == .both { #expect(newcomer.outcome == .success) }
        #expect(await fixture.server.subscriptions == 1)
        #expect(await fixture.server.cancellations == 0)
        #expect(fixture.services.revision == 1)
        #expect(fixture.services.refreshWaiterCount == 0)
    }

    @Test("All joined callers receive failure and the next automatic request retries", .timeLimit(.minutes(1)),
          arguments: [false, true])
    func sharedFailureReleasesCallersAndPermitsRetry(forceJoiner: Bool) async throws {
        let fixture = try await RefreshFixture(failFirst: true)
        let a = RefreshCompletion()
        let b = RefreshCompletion()
        let first = start(fixture.services, completion: a)
        defer { first.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        let second = start(fixture.services, completion: b, force: forceJoiner)
        defer { second.cancel() }
        #expect(await waitUntil { fixture.services.refreshWaiterCount == 2 })
        await fixture.gate.open()
        await first.value
        await second.value
        #expect(a.outcome == .server(503))
        #expect(b.outcome == .server(503))
        #expect(fixture.services.refreshWaiterCount == 0)
        #expect(fixture.services.revision == 0)
        #expect(await fixture.server.subscriptions == 1)
        try await fixture.services.refreshIfNeeded()
        #expect(await fixture.server.subscriptions == 2)
        #expect(fixture.services.revision == 1)
        try await fixture.services.refreshIfNeeded()
        #expect(await fixture.server.subscriptions == 2)
    }

    @Test("An already-cancelled window cannot start account refresh", .timeLimit(.minutes(1)))
    func alreadyCancelledCallerCannotStartRefresh() async throws {
        let fixture = try await RefreshFixture()
        let completion = RefreshCompletion()
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            completion.outcome = await outcome(fixture.services)
        }
        defer { request.cancel(); Task { await fixture.gate.open() } }
        #expect(await waitUntil { completion.outcome != nil })
        await fixture.gate.open()
        await request.value
        #expect(completion.outcome == .cancelled)
        #expect(await fixture.server.subscriptions == 0)
        #expect(fixture.services.revision == 0)
        #expect(fixture.services.refreshWaiterCount == 0)
    }

    private func start(_ services: ReaderServices, completion: RefreshCompletion,
                       force: Bool = false) -> Task<Void, Never> {
        Task { completion.outcome = await outcome(services, force: force) }
    }

    private func outcome(_ services: ReaderServices, force: Bool = false) async -> RefreshOutcome {
        do {
            try await services.refreshIfNeeded(force: force)
            return .success
        } catch is CancellationError {
            return .cancelled
        } catch ReaderError.server(let status) {
            return .server(status)
        } catch {
            return .unexpected(error.localizedDescription)
        }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, timeout: Duration = .seconds(1)) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            if Task.isCancelled || ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}

private enum RefreshOutcome: Equatable, Sendable { case success, cancelled, server(Int), unexpected(String) }

@MainActor
private final class RefreshCompletion {
    var outcome: RefreshOutcome?
}

@MainActor
private final class RefreshFixture {
    let store: ReaderStore
    let services: ReaderServices
    let server: RefreshServer
    let transport: URLSession
    let gate = RequestGate()
    let host: String

    init(failFirst: Bool = false) async throws {
        host = UUID().uuidString.lowercased() + ".refresh.test"
        store = try ReaderStore(inMemory: true)
        let account = ReaderAccount(serverURL: try #require(URL(string: "https://" + host)), username: "refresh-fixture")
        try await store.saveAccount(account)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        transport = URLSession(configuration: configuration)
        server = RefreshServer(gate: gate, failFirst: failFirst)
        let server = server
        MockURLProtocol.register(host: host) { try await server.respond($0) }
        let client = FreshRSSClient(repository: store, credentials: RefreshCredentials(), session: transport)
        services = ReaderServices(repository: store, client: client)
    }

    deinit {
        transport.invalidateAndCancel()
        MockURLProtocol.unregister(host: host)
    }
}

private actor RefreshCredentials: CredentialStore {
    func password(accountID: UUID) -> String? { "fixture-api-password" }
    func savePassword(_ password: String, accountID: UUID) { }
    func removePassword(accountID: UUID) { }
}

private actor RefreshServer {
    private let gate: RequestGate
    private let failFirst: Bool
    private(set) var subscriptions = 0
    private(set) var cancellations = 0

    init(gate: RequestGate, failFirst: Bool) { self.gate = gate; self.failFirst = failFirst }

    func respond(_ request: URLRequest) async throws -> (Int, Data) {
        guard let url = request.url else { throw ReaderError.invalidURL }
        let body: String
        if url.path.hasSuffix("ClientLogin") {
            body = "SID=fixture\nAuth=fixture-auth\n"
        } else if url.path.hasSuffix("subscription/list") {
            subscriptions += 1
            let current = subscriptions
            do { try await gate.pause() } catch is CancellationError {
                cancellations += 1
                throw CancellationError()
            }
            if failFirst && current == 1 { return (503, Data("Unavailable".utf8)) }
            body = #"{"subscriptions":[]}"#
        } else if url.path.hasSuffix("tag/list") {
            body = #"{"tags":[]}"#
        } else if url.path.hasSuffix("stream/items/ids") {
            body = #"{"itemRefs":[]}"#
        } else if url.path.hasSuffix("token") {
            body = "fixture-token"
        } else {
            body = "{}"
        }
        return (200, Data(body.utf8))
    }
}
