import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderSync
@testable import ReaderUI

@MainActor
struct ReaderConnectionTests {
    enum InvalidInput: CaseIterable, Sendable { case emptyServer, insecureServer, missingHost, relativeURL, emptyUsername, emptyPassword }

    @Test("Invalid connection input cannot save credentials, create accounts or start HTTP",
          arguments: InvalidInput.allCases)
    func invalidConnectionInputHasNoSideEffects(input: InvalidInput) async throws {
        let fixture = try ConnectionFixture()
        var server = fixture.url.absoluteString
        var username = "fixture-user"
        var password = "fixture-api-password"
        switch input {
        case .emptyServer: server = ""
        case .insecureServer: server = "http://" + fixture.host
        case .missingHost: server = "https://"
        case .relativeURL: server = "relative/path"
        case .emptyUsername: username = ""
        case .emptyPassword: password = ""
        }
        await #expect(throws: ReaderError.invalidURL) {
            try await fixture.session.connect(server: server, username: username, password: password)
        }
        #expect(await fixture.credentials.saves == 0)
        #expect(await fixture.requests.count == 0)
        #expect(try await fixture.store.accounts().isEmpty)
        #expect(fixture.session.accounts.isEmpty)
    }

    @Test("Valid connection input uses the configured services and publishes the persisted account")
    func validConnectionPublishesPersistedAccount() async throws {
        let fixture = try ConnectionFixture()
        try await fixture.session.connect(server: fixture.url.absoluteString, username: "fixture-user", password: "fixture-api-password")
        let accounts = try await fixture.store.accounts()
        let account = try #require(accounts.first)
        #expect(accounts.count == 1)
        #expect(account.username == "fixture-user")
        #expect(account.serverURL == fixture.url)
        #expect(fixture.session.accounts.map(\.id) == [account.id])
        #expect(await fixture.credentials.saves == 1)
        #expect(await fixture.requests.count > 0)
        #expect(fixture.session.errorMessage == nil)
    }
}

@MainActor
private final class ConnectionFixture {
    let host: String
    let url: URL
    let store: ReaderStore
    let credentials = ConnectionCredentials()
    let requests = ConnectionRequests()
    let transport: URLSession
    let session: ReaderSession

    init() throws {
        host = UUID().uuidString.lowercased() + ".connection.test"
        url = try #require(URL(string: "https://" + host))
        store = try ReaderStore(inMemory: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        transport = URLSession(configuration: configuration)
        let requests = requests
        MockURLProtocol.register(host: host) { request in
            await requests.record()
            let path = request.url?.path ?? ""
            let body: String
            if path.hasSuffix("ClientLogin") {
                body = "Auth=fixture-auth\n"
            } else if path.hasSuffix("subscription/list") {
                body = #"{"subscriptions":[]}"#
            } else if path.hasSuffix("tag/list") {
                body = #"{"tags":[]}"#
            } else if path.hasSuffix("stream/items/ids") {
                body = #"{"itemRefs":[]}"#
            } else {
                throw ReaderError.invalidResponse
            }
            return (200, Data(body.utf8))
        }
        let client = FreshRSSClient(repository: store, credentials: credentials, session: transport)
        session = ReaderSession(services: ReaderServices(repository: store, credentials: credentials, client: client))
    }

    deinit {
        transport.invalidateAndCancel()
        MockURLProtocol.unregister(host: host)
    }
}

private actor ConnectionCredentials: CredentialStore {
    private var values: [UUID: String] = [:]
    private(set) var saves = 0
    func password(accountID: UUID) -> String? { values[accountID] }
    func savePassword(_ password: String, accountID: UUID) { values[accountID] = password; saves += 1 }
    func removePassword(accountID: UUID) { values[accountID] = nil }
}

private actor ConnectionRequests {
    private(set) var count = 0
    func record() { count += 1 }
}
