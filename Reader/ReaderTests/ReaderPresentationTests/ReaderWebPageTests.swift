import Foundation
import Testing
import WebKit
import ReaderDomain
@testable import ReaderUI

@MainActor
struct ReaderWebPageTests {
    @Test("The shipping WebPage loads saved HTML without executing page scripts", .timeLimit(.minutes(1)))
    func savedHTMLLoadsWithoutPageScripts() async throws {
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        let article = makeArticle(html: "<h1>Saved offline content</h1><script>document.body.dataset.executed='yes'</script>")
        for try await _ in page.load(html: ReaderArticleDocument.html(for: article), baseURL: baseURL) { }
        let text = try await page.callJavaScript("return document.body.textContent;") as? String
        #expect(text?.contains("Saved offline content") == true)
        let executed = try await page.callJavaScript("return document.body.dataset.executed || 'no';") as? String
        #expect(executed == "no")
    }

    @Test("Page script policy stays disabled independently of the document CSP", .timeLimit(.minutes(1)))
    func scriptPolicyDoesNotDependOnDocumentCSP() async throws {
        var configuration = WebPage.Configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let page = ReaderArticleDocument.makePage(configuration: configuration)
        defer { page.stopLoading() }
        for try await _ in page.load(html: "<body><p>Saved text</p><script>document.body.dataset.executed='yes'</script></body>",
                                    baseURL: baseURL) { }
        let executed = try await page.callJavaScript("return document.body.dataset.executed || 'no';") as? String
        #expect(executed == "no")
    }

    @Test("Saved plain text remains literal in the actual WebKit document", .timeLimit(.minutes(1)),
          arguments: ["<script>document.body.dataset.executed='yes'</script>", "A & B <em>literal</em>", "Café EUR 2.99\nSecond line"])
    func savedPlainTextRemainsLiteral(text: String) async throws {
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        let article = makeArticle(html: "", text: text)
        for try await _ in page.load(html: ReaderArticleDocument.html(for: article), baseURL: baseURL) { }
        let actual = try await page.callJavaScript("return document.querySelector('pre').textContent;") as? String
        #expect(actual == text)
        let inserted = try await page.callJavaScript("return document.querySelectorAll('script,img,em').length;") as? Int
        #expect(inserted == 0)
    }

    @Test("Malformed saved markup preserves text, tables, image data and relative links", .timeLimit(.minutes(1)),
          arguments: [0, 1, 2])
    func malformedSavedMarkupRenders(kind: Int) async throws {
        let image = "<svg xmlns='http://www.w3.org/2000/svg' width='80' height='40'><rect width='80' height='40' fill='teal'/></svg>"
        let source = "data:image/svg+xml;base64," + Data(image.utf8).base64EncodedString()
        let link = "<a id='relative' href='../offer'>Relative offer</a>"
        let illustration = "<img id='illustration' alt='Saved illustration' src='" + source + "'>"
        let fragment: String
        switch kind {
        case 0: fragment = "<article><h1>Saved heading</h1><p>Saved paragraph" + link + illustration + "<table><tr><td>Offline cell"
        case 1: fragment = "<ARTICLE><H1>Saved heading</H1><P>Saved paragraph" + link + "<TABLE><TR><TD>Offline cell</TABLE>" + illustration
        default: fragment = "<section><!-- incomplete feed markup --><h1>Saved heading</h1><p>Saved paragraph</div>" + link +
                            "<table><tbody><tr><td>Offline cell</table>" + illustration
        }
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        for try await _ in page.load(html: ReaderArticleDocument.html(for: makeArticle(html: fragment)), baseURL: baseURL) { }
        let body = try await page.callJavaScript("return document.body.textContent;") as? String
        #expect(body?.contains("Saved paragraph") == true)
        #expect(body?.contains("Offline cell") == true)
        let target = try await page.callJavaScript("return document.querySelector('#relative').href;") as? String
        #expect(target == "https://offline.reader.invalid/offer")
        let width = try await page.callJavaScript("return document.querySelector('#illustration').naturalWidth;") as? Int
        let height = try await page.callJavaScript("return document.querySelector('#illustration').naturalHeight;") as? Int
        #expect(width == 80)
        #expect(height == 40)
    }

    enum NavigationOutcome: CaseIterable, Sendable { case success, failure, cancelled }

    @Test("Real WebPages and custom resource handlers release after navigation ends", .timeLimit(.minutes(1)),
          arguments: NavigationOutcome.allCases)
    func nativePageGraphsRelease(outcome: NavigationOutcome) async throws {
        let graph = try await exercisePage(outcome)
        #expect(try await waitUntil { graph.released }, Comment(rawValue: graph.retained))
    }

    private func exercisePage(_ outcome: NavigationOutcome) async throws -> WeakPageGraph {
        let server = PageResourceServer(outcome: outcome)
        let handler = PageResourceHandler(server: server)
        let scheme = try #require(URLScheme("reader-page-fixture"))
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[scheme] = handler
        let page = ReaderArticleDocument.makePage(configuration: configuration)
        let graph = WeakPageGraph(page: page, handler: handler, server: server)
        let url = try #require(URL(string: "reader-page-fixture://saved/document"))
        let completion = PageNavigationCompletion()
        let navigation = Task { [page] in
            do {
                for try await _ in page.load(URLRequest(url: url)) { }
                try Task.checkCancellation()
                completion.outcome = .success
            } catch { completion.outcome = Task.isCancelled ? .cancelled : .failure }
        }
        defer { navigation.cancel(); page.stopLoading(); Task { await server.gate.open() } }
        if outcome == .cancelled {
            try await server.gate.waitUntilEntered()
            page.stopLoading()
            navigation.cancel()
            #expect(try await waitUntil { completion.outcome != nil })
            #expect(try await waitUntil { await server.cancellations == 1 })
        }
        await navigation.value
        #expect(completion.outcome == outcome)
        #expect(await server.requests == 1)
        return graph
    }

    private var baseURL: URL { URL(string: "https://offline.reader.invalid/articles/saved")! }

    private func makeArticle(html: String, text: String = "") -> ArticleSnapshot {
        ArticleSnapshot(id: ArticleKey(accountID: UUID(), remoteID: "saved"), feedID: "feed",
                        title: "Saved article", html: html, text: text)
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

@MainActor
private final class PageNavigationCompletion { var outcome: ReaderWebPageTests.NavigationOutcome? }

nonisolated private final class PageResourceHandler: URLSchemeHandler, Sendable {
    let server: PageResourceServer
    init(server: PageResourceServer) { self.server = server }

    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let data = try await server.response()
                    let url = try #require(request.url)
                    continuation.yield(.response(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")))
                    continuation.yield(.data(data))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private actor PageResourceServer {
    let outcome: ReaderWebPageTests.NavigationOutcome
    let gate = RequestGate()
    private(set) var requests = 0
    private(set) var cancellations = 0

    init(outcome: ReaderWebPageTests.NavigationOutcome) { self.outcome = outcome }

    func response() async throws -> Data {
        requests += 1
        if outcome == .cancelled {
            do { try await gate.pause() } catch {
                if Task.isCancelled { cancellations += 1 }
                throw error
            }
        }
        if outcome == .failure { throw URLError(.cannotConnectToHost) }
        return Data("<html><body><p>Saved native document</p></body></html>".utf8)
    }
}

@MainActor
private final class WeakPageGraph {
    weak var page: WebPage?
    weak var handler: PageResourceHandler?
    weak var server: PageResourceServer?
    init(page: WebPage, handler: PageResourceHandler, server: PageResourceServer) {
        self.page = page; self.handler = handler; self.server = server
    }
    var released: Bool { page == nil && handler == nil && server == nil }
    var retained: String { "page=\(page != nil), handler=\(handler != nil), server=\(server != nil)" }
}
