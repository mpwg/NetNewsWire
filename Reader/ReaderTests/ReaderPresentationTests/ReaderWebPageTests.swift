import Foundation
import Testing
import WebKit
import ReaderDomain
import ReaderContent
import Synchronization
@testable import ReaderUI

@MainActor
struct ReaderWebPageTests {
    @Test("The shipping WebPage loads saved HTML without executing page scripts", .timeLimit(.minutes(1)))
    func savedHTMLLoadsWithoutPageScripts() async throws {
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        let article = makeArticle(html: "<h1>Saved offline content</h1><script>document.body.dataset.executed='yes'</script>")
        try await ReaderArticleDocument.load(article, into: page)
        let text = try await page.callJavaScript("return document.body.textContent;") as? String
        #expect(text?.contains("Saved offline content") == true)
        let executed = try await page.callJavaScript("return document.body.dataset.executed || 'no';") as? String
        #expect(executed == "no")
    }

    @Test("Page script policy stays disabled independently of the document CSP", .timeLimit(.minutes(1)))
    func scriptPolicyDoesNotDependOnDocumentCSP() async throws {
        var configuration = WebPage.Configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let control = WebPage(configuration: configuration)
        defer { control.stopLoading() }
        for try await _ in control.load(html: "<body><script>document.body.dataset.executed='yes'</script></body>") { }
        #expect(try await control.callJavaScript("return document.body.dataset.executed;") as? String == "yes")
        configuration.userContentController.addUserScript(WKUserScript(source: "document.documentElement.dataset.injected='yes'",
                                                                       injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        let page = ReaderArticleDocument.makePage(configuration: configuration)
        defer { page.stopLoading() }
        for try await _ in page.load(html: "<body><p>Saved text</p><script>document.body.dataset.executed='yes'</script></body>") { }
        let executed = try await page.callJavaScript("return document.body.dataset.executed || 'no';") as? String
        #expect(executed == "no")
        #expect(try await page.callJavaScript("return document.documentElement.dataset.injected || 'no';") as? String == "no")
    }

    @Test("Saved plain text remains literal in the actual WebKit document", .timeLimit(.minutes(1)),
          arguments: ["<script>document.body.dataset.executed='yes'</script>", "A & B <em>literal</em>", "Café EUR 2.99\nSecond line"])
    func savedPlainTextRemainsLiteral(text: String) async throws {
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        let article = makeArticle(html: "", text: text)
        try await ReaderArticleDocument.load(article, into: page)
        let actual = try await page.callJavaScript("return document.querySelector('pre').textContent;") as? String
        #expect(actual == text)
        let inserted = try await page.callJavaScript("return document.querySelectorAll('script,img,em').length;") as? Int
        #expect(inserted == 0)
    }

    @Test("Malformed saved markup preserves text, tables and links while removing all images", .timeLimit(.minutes(1)),
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
        try await ReaderArticleDocument.load(makeArticle(html: fragment), into: page)
        let body = try await page.callJavaScript("return document.body.textContent;") as? String
        #expect(body?.contains("Saved paragraph") == true)
        #expect(body?.contains("Offline cell") == true)
        let target = try await page.callJavaScript("return document.querySelector('#reader-source-relative').href;") as? String
        #expect(target == "https://offline.reader.invalid/offer")
        #expect(body?.contains("Saved illustration") == true)
        let images = try await page.callJavaScript("return document.querySelectorAll('img,svg').length;") as? Int
        #expect(images == 0)
    }

    @Test("Publisher CSS and active markup never enter the visible article DOM", .timeLimit(.minutes(1)),
          arguments: [0, 1, 2, 3, 4, 5])
    func activeArticleContentIsRemoved(kind: Int) async throws {
        let attacks = [
            "<style>@keyframes pulse{to{opacity:0}}body{font-size:99px!important;animation:pulse 1s infinite}</style><p style='font-size:99px;animation:pulse 1s infinite' onclick='window.readerExecuted=1'>Passive marker</p>",
            "<script>window.readerExecuted=1</script><img src='data:image/svg+xml,%3Csvg%20onload=alert(1)%3E' onerror='window.readerExecuted=1' alt='Image alternative'><p>Passive marker</p>",
            "<svg xmlns='http://www.w3.org/2000/svg' onload='window.readerExecuted=1'><animate attributeName='opacity'/><foreignObject><p>Hidden active content</p></foreignObject></svg><math><mtext>Hidden active content</mtext></math><p>Passive marker</p>",
            "<iframe srcdoc='<script>parent.readerExecuted=1</script>'></iframe><object data='reader-resource://blocked/object'></object><embed src='reader-resource://blocked/embed'><p>Passive marker</p>",
            "<form action='https://blocked.invalid/'><input autofocus><button>Submit</button></form><video autoplay src='reader-resource://blocked/media'></video><audio autoplay></audio><canvas>Hidden active content</canvas><p>Passive marker</p>",
            "<meta http-equiv='refresh' content='0;url=reader-resource://blocked/redirect'><base href='https://blocked.invalid/'><link rel='stylesheet' href='reader-resource://blocked/style'><marquee>Hidden active content</marquee><p contenteditable autofocus class='publisher' data-script='x'>Passive marker</p>"
        ]
        let resources = ReaderResourceCanary()
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[try #require(URLScheme("reader-resource"))] = resources
        let page = ReaderArticleDocument.makePage(configuration: configuration)
        defer { page.stopLoading() }
        try await ReaderArticleDocument.load(makeArticle(html: attacks[kind]), into: page)
        let state = try await page.callJavaScript("""
        return JSON.stringify({
          text:document.body.textContent,
          active:document.body.querySelectorAll('script,style,link,meta,base,img,svg,math,iframe,object,embed,form,input,button,video,audio,canvas,marquee').length,
          attributes:document.body.querySelectorAll('[style],[class],[onclick],[onload],[onerror],[contenteditable],[autofocus]').length,
          executed:window.readerExecuted || 0,
          animations:document.getAnimations().length,
          font:getComputedStyle(document.body).fontSize,
          location:location.href
        });
        """, contentWorld: .defaultClient) as? String
        let values = try #require(state.flatMap { $0.data(using: .utf8) })
        let result = try #require(JSONSerialization.jsonObject(with: values) as? [String: Any])
        #expect((result["text"] as? String)?.contains("Passive marker") == true)
        #expect((result["text"] as? String)?.contains("Hidden active content") == false)
        #expect(result["active"] as? Int == 0)
        #expect(result["attributes"] as? Int == 0)
        #expect(result["executed"] as? Int == 0)
        #expect(result["animations"] as? Int == 0)
        #expect(result["font"] as? String == "17px")
        #expect(result["location"] as? String == "about:blank")
        #expect(resources.requests.withLock { $0.isEmpty })
    }

    @Test("Native content rules block resource loads independently of the document CSP", .timeLimit(.minutes(1)))
    func nativeRulesBlockResourcesWithoutCSP() async throws {
        let resources = ReaderResourceCanary()
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[try #require(URLScheme("reader-resource"))] = resources
        let image = "<body><img src='reader-resource://canary/image'></body>"
        let control = WebPage(configuration: configuration)
        defer { control.stopLoading() }
        for try await _ in control.load(html: image) { }
        #expect(resources.requests.withLock { $0.count } == 1)
        resources.requests.withLock { $0.removeAll() }
        configuration = ReaderWebContentPolicy.configuration(configuration)
        configuration.loadsSubresources = true
        let page = WebPage(configuration: configuration,
                           navigationDecider: ReaderWebNavigationPolicy(controller: configuration.userContentController))
        defer { page.stopLoading() }
        for try await _ in page.load(html: image) { }
        #expect(resources.requests.withLock { $0.isEmpty })
    }

    @Test("The document CSP accepts only Reader's exact style even if sanitization is bypassed", .timeLimit(.minutes(1)))
    func cspRejectsPublisherStyleIndependently() async throws {
        let attack = "<style>body{font-size:99px!important}p{font-size:88px!important}</style><p style='font-size:77px!important'>Style canary</p>"
        let control = WebPage()
        defer { control.stopLoading() }
        for try await _ in control.load(html: attack) { }
        #expect(try await control.callJavaScript("return getComputedStyle(document.body).fontSize;") as? String == "99px")
        #expect(try await control.callJavaScript("return getComputedStyle(document.querySelector('p')).fontSize;") as? String == "77px")
        // Deliberately bypass the sanitizer to verify this separate browser boundary.
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        for try await _ in page.load(html: ReaderArticleDocument.html(safeContent: attack)) { }
        #expect(try await page.callJavaScript("return getComputedStyle(document.body).fontSize;") as? String == "17px")
        #expect(try await page.callJavaScript("return getComputedStyle(document.querySelector('p')).fontSize;") as? String == "17px")
    }

    @Test("Unsafe link protocols and embedded credentials are removed", .timeLimit(.minutes(1)),
          arguments: ["javascript:alert(1)", "data:text/html,hello", "file:///etc/hosts", "blob:https://example.invalid/id",
                      "mailto:reader@example.invalid", "https://user:secret@example.invalid/", "about:srcdoc"])
    func unsafeArticleLinksHaveNoDestination(destination: String) async throws {
        let page = ReaderArticleDocument.makePage()
        defer { page.stopLoading() }
        try await ReaderArticleDocument.load(makeArticle(html: "<a href='" + destination + "'>Unsafe destination</a>"), into: page)
        #expect(try await page.callJavaScript("return document.querySelector('a').hasAttribute('href');") as? Bool == false)
        #expect(!ReaderWebContentPolicy.permitsExternalLink(try #require(URL(string: destination))))
    }

    @Test("A safe link is routed outside the article without navigating its WebPage", .timeLimit(.minutes(1)))
    func safeLinksUseTheExternalHandler() async throws {
        let opened = ReaderOpenedLinks()
        let page = ReaderArticleDocument.makePage(openLink: { opened.values.append($0) })
        defer { page.stopLoading() }
        try await ReaderArticleDocument.load(makeArticle(html: "<a href='../offer'>Open offer</a>"), into: page)
        _ = try await page.callJavaScript("document.querySelector('a').click();", contentWorld: .defaultClient)
        #expect(try await waitUntil { opened.values.count == 1 })
        #expect(opened.values.first?.absoluteString == "https://offline.reader.invalid/offer")
        #expect(try await page.callJavaScript("return location.href;") as? String == "about:blank")
    }

    enum NavigationOutcome: CaseIterable, Sendable { case success, failure, cancelled }

    @Test("Shipping article WebPages release after success, rejected content and cancellation", .timeLimit(.minutes(1)),
          arguments: NavigationOutcome.allCases)
    func nativePageGraphsRelease(outcome: NavigationOutcome) async throws {
        let graph = try await exercisePage(outcome)
        #expect(try await waitUntil { graph.released }, Comment(rawValue: graph.retained))
    }

    private func exercisePage(_ outcome: NavigationOutcome) async throws -> WeakPageGraph {
        let gate = RequestGate()
        let page: WebPage
        if outcome == .cancelled {
            page = WebPage(configuration: ReaderWebContentPolicy.configuration(),
                           navigationDecider: HeldReaderNavigation(gate: gate))
        } else { page = ReaderArticleDocument.makePage() }
        let graph = WeakPageGraph(page: page, gate: gate)
        let completion = PageNavigationCompletion()
        let article = makeArticle(html: outcome == .failure ? String(repeating: "x", count: 4_000_001) : "<p>Saved native document</p>")
        let navigation = Task {
            do {
                try await ReaderArticleDocument.load(article, into: page)
                completion.outcome = .success
            } catch {
                if Task.isCancelled { completion.outcome = .cancelled } else {
                    #expect(error as? ReaderError == .invalidResponse)
                    completion.outcome = .failure
                }
            }
        }
        defer { navigation.cancel(); page.stopLoading(); Task { await gate.open() } }
        if outcome == .cancelled {
            try await gate.waitUntilEntered()
            navigation.cancel()
            let ended = try await waitUntil { completion.outcome != nil }
            #expect(ended, "The shipping document task must finish while navigation is still held.")
            if !ended { await gate.open() }
        }
        await navigation.value
        #expect(completion.outcome == outcome)
        return graph
    }

    private var baseURL: URL { URL(string: "https://offline.reader.invalid/articles/saved")! }

    private func makeArticle(html: String, text: String = "") -> ArticleSnapshot {
        ArticleSnapshot(id: ArticleKey(accountID: UUID(), remoteID: "saved"), feedID: "feed",
                        title: "Saved article", html: html, text: text, url: baseURL)
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

private struct HeldReaderNavigation: WebPage.NavigationDeciding {
    let gate: RequestGate
    @MainActor
    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        do { try await gate.pause() } catch { return .cancel }
        return await ReaderWebNavigationPolicy().decidePolicy(for: action, preferences: &preferences)
    }
}

@MainActor
private final class WeakPageGraph {
    weak var page: WebPage?
    weak var gate: RequestGate?
    init(page: WebPage, gate: RequestGate) { self.page = page; self.gate = gate }
    var released: Bool { page == nil && gate == nil }
    var retained: String { "page=\(page != nil), gate=\(gate != nil)" }
}

private final class ReaderResourceCanary: URLSchemeHandler, Sendable {
    let requests = Mutex<[String]>([])
    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        requests.withLock { $0.append(request.url?.absoluteString ?? "") }
        return AsyncThrowingStream { continuation in
            guard let url = request.url else { continuation.finish(throwing: ReaderError.invalidURL); return }
            let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a0uoAAAAASUVORK5CYII=")!
            continuation.yield(.response(URLResponse(url: url, mimeType: "image/png", expectedContentLength: data.count, textEncodingName: nil)))
            continuation.yield(.data(data))
            continuation.finish()
        }
    }
}

@MainActor
private final class ReaderOpenedLinks { var values: [URL] = [] }
