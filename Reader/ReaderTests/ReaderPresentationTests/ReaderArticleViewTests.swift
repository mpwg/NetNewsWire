#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
import WebKit
import ReaderContent
import ReaderDomain
import ReaderPersistence
@testable import ReaderUI

@MainActor
struct ReaderArticleViewTests {
    enum Outcome: CaseIterable, Sendable { case success, failure, empty, cancelled }

    @Test("Removing the actual hosted article view ends extraction and releases its graph",
          .timeLimit(.minutes(1)), arguments: Outcome.allCases)
    func removingHostedArticleReleasesItsGraph(outcome: Outcome) async throws {
        let graph = try await exerciseView(outcome)
        #expect(try await waitUntil { graph.released }, Comment(rawValue: graph.retained))
    }

    private func exerciseView(_ outcome: Outcome) async throws -> WeakArticleViewGraph {
        _ = NSApplication.shared
        let fixture = try await ArticleViewFixture(outcome: outcome)
        let reader = ReaderArticleState()
        let host = NSHostingView(rootView: AnyView(ArticleViewHost(session: fixture.session, reader: reader)))
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 960, height: 640),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Reader native view fixture"
        window.contentView = host
        let graph = WeakArticleViewGraph(fixture: fixture, reader: reader, host: host)
        defer {
            host.rootView = AnyView(EmptyView())
            window.contentView = nil
            window.close()
            Task { await fixture.server.gate.open() }
        }
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        #expect(try await waitUntil {
            (try? await reader.page.callJavaScript("return document.body && document.body.textContent.includes('Saved native article');")) as? Bool == true
        })
        reader.beginExtraction()
        #expect(try await waitUntil { await fixture.server.requests == 1 })
        if outcome == .cancelled {
            try await fixture.server.gate.waitUntilEntered()
            #expect(reader.extracting)
        } else {
            #expect(try await waitUntil { !reader.extracting })
            if outcome == .failure || outcome == .empty {
                #expect(fixture.session.fullTextError != nil)
                if outcome == .failure { #expect(fixture.session.fullTextError == ReaderError.server(403).localizedDescription) }
                let saved = try await reader.page.callJavaScript("return document.body.textContent;") as? String
                #expect(saved?.contains("Saved native article") == true)
            } else {
                #expect(fixture.session.errorMessage == nil)
                #expect(fixture.session.fullTextError == nil)
                #expect(fixture.services.revision == 1)
                #expect(await fixture.server.cancellations == 0)
                #expect(fixture.session.selection == .article(fixture.article.id))
                let current = try #require(fixture.session.selectedArticle)
                #expect(current.text.contains("Extracted native article"))
                #expect(try await waitUntil {
                    (try? await reader.page.callJavaScript("return document.body && document.body.textContent.includes('Extracted native article');")) as? Bool == true
                })
            }
        }
        window.displayIfNeeded()
        host.layoutSubtreeIfNeeded()
        host.rootView = AnyView(EmptyView())
        host.layoutSubtreeIfNeeded()
        #expect(try await waitUntil { !reader.extracting })
        if outcome == .cancelled {
            #expect(try await waitUntil { await fixture.server.cancellations == 1 })
            #expect(fixture.session.errorMessage == nil)
            #expect(try await fixture.store.article(fixture.article.id) == fixture.article)
        }
        #expect(try await fixture.store.pendingChanges(accountID: fixture.article.id.accountID).isEmpty)
        return graph
    }

    private func waitUntil(_ condition: () async -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await condition()) {
            if ContinuousClock.now >= deadline { return false }
            try await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}

private struct ArticleViewHost: View {
    let session: ReaderSession
    let reader: ReaderArticleState
    var body: some View {
        if let article = session.selectedArticle {
            ArticleDetailView(session: session, article: article, reader: reader).id(article.id)
        }
    }
}

@MainActor
private final class ArticleViewFixture {
    let store: ReaderStore
    let transport: URLSession
    let content: ArticleContentService
    let services: ReaderServices
    let session: ReaderSession
    let server: ArticleViewServer
    let article: ArticleSnapshot
    let host: String

    init(outcome: ReaderArticleViewTests.Outcome) async throws {
        host = UUID().uuidString.lowercased() + ".article-view.test"
        let base = try #require(URL(string: "https://" + host))
        let account = ReaderAccount(serverURL: base, username: "native-view-fixture")
        let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "feed"), title: "Fixture feed", url: base)
        article = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "article"), feedID: feed.id.remoteID,
                                  title: "Saved article", html: "<h1>Saved native article</h1><p>Saved feed content remains available.</p>",
                                  text: "Saved native article", url: base.appendingPathComponent("article"))
        store = try ReaderStore(inMemory: true)
        try await store.saveAccount(account)
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: [article],
                                                    unreadIDs: ["article"], starredIDs: []))
        server = ArticleViewServer(outcome: outcome)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        transport = URLSession(configuration: configuration)
        content = ArticleContentService(session: transport)
        services = ReaderServices(repository: store, content: content)
        session = ReaderSession(services: services)
        let server = server
        MockURLProtocol.register(host: host, mimeType: "text/html; charset=utf-8") { _ in try await server.response() }
        await session.reload()
        session.selection = .article(article.id)
    }

    deinit {
        MockURLProtocol.unregister(host: host)
        transport.invalidateAndCancel()
    }
}

private actor ArticleViewServer {
    let outcome: ReaderArticleViewTests.Outcome
    let gate = RequestGate()
    private(set) var requests = 0
    private(set) var cancellations = 0

    init(outcome: ReaderArticleViewTests.Outcome) { self.outcome = outcome }

    func response() async throws -> (Int, Data) {
        requests += 1
        if outcome == .cancelled {
            do { try await gate.pause() } catch {
                if Task.isCancelled { cancellations += 1 }
                throw error
            }
        }
        if outcome == .failure { return (403, Data("Access denied".utf8)) }
        if outcome == .empty { return (200, Data("<html><body></body></html>".utf8)) }
        let text = String(repeating: "Extracted native article with representative content. ", count: 40)
        return (200, Data(("<article><h1>Extracted native article</h1><p>" + text + "</p></article>").utf8))
    }
}

@MainActor
private final class WeakArticleViewGraph {
    weak var reader: ReaderArticleState?
    weak var page: WebPage?
    weak var host: NSHostingView<AnyView>?
    weak var session: ReaderSession?
    weak var services: ReaderServices?
    weak var content: ArticleContentService?
    weak var store: ReaderStore?
    weak var transport: URLSession?
    weak var server: ArticleViewServer?

    init(fixture: ArticleViewFixture, reader: ReaderArticleState, host: NSHostingView<AnyView>) {
        self.reader = reader; page = reader.page; self.host = host; session = fixture.session; services = fixture.services
        content = fixture.content; store = fixture.store; transport = fixture.transport; server = fixture.server
    }

    var released: Bool {
        reader == nil && page == nil && host == nil && session == nil && services == nil &&
        content == nil && store == nil && transport == nil && server == nil
    }
    var retained: String {
        "reader=\(reader != nil), page=\(page != nil), host=\(host != nil), session=\(session != nil), services=\(services != nil), " +
        "content=\(content != nil), store=\(store != nil), transport=\(transport != nil), server=\(server != nil)"
    }
}
#endif
