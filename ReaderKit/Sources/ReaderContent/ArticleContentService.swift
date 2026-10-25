import Foundation
import WebKit
import Synchronization
import ReaderDomain

public struct ExtractedContent: Hashable, Sendable {
    public var html: String
    public var text: String
    public init(html: String, text: String) { self.html = html; self.text = text }
}

public protocol ArticleContentExtracting: Sendable {
    func extract(url: URL) async throws -> ExtractedContent
}

/// Fetches bounded article data and extracts content from inert native HTML documents.
public actor ArticleContentService: ArticleContentExtracting {
    private let session: URLSession
    private var activeExtractions = 0
    private var waitingExtractions = 0
    var waitingExtractionCount: Int { waitingExtractions }
    public init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    public func extract(url: URL) async throws -> ExtractedContent {
        guard ReaderWebContentPolicy.permitsExternalLink(url) else { throw ReaderError.invalidURL }
        try await acquireExtraction()
        defer { activeExtractions -= 1 }
        let download = BoundedArticleDownload(maximumBytes: 4_000_000)
        let (data, response) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                request.setValue("text/html, application/xhtml+xml", forHTTPHeaderField: "Accept")
                download.start(request, session: session, continuation: continuation)
            }
        } onCancel: { download.cancel() }
        try Task.checkCancellation()
        guard data.count <= 4_000_000,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ReaderError.invalidResponse
        }
        return try await parse(html: html, baseURL: response.url ?? url)
    }

    public func extract(html: String, baseURL: URL) async throws -> ExtractedContent {
        try await acquireExtraction()
        defer { activeExtractions -= 1 }
        return try await parse(html: html, baseURL: baseURL)
    }

    private func acquireExtraction() async throws {
        waitingExtractions += 1
        defer { waitingExtractions -= 1 }
        while activeExtractions >= 2 {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(10))
        }
        try Task.checkCancellation()
        activeExtractions += 1
    }

    private func parse(html: String, baseURL: URL) async throws -> ExtractedContent {
        try Task.checkCancellation()
        guard html.utf8.count <= 4_000_000 else { throw ReaderError.invalidResponse }
        let script = try ArticleHTMLParser.readabilitySource()
        return try await ArticleHTMLParser.extract(html: html, baseURL: baseURL, readability: script)
    }
}

/// Parses local HTML with WebKit, never navigating to the source website.
@MainActor
enum ArticleHTMLParser {
    nonisolated static func readabilitySource() throws -> String {
        guard let path = Bundle.module.url(forResource: "Readability", withExtension: "js") else {
            throw ReaderError.unavailable(String(localized: "The local full-text parser is missing.", bundle: #bundle))
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    static func makePage(configuration: WebPage.Configuration = WebPage.Configuration()) -> WebPage {
        let configuration = ReaderWebContentPolicy.configuration(configuration)
        return WebPage(configuration: configuration, navigationDecider: ReaderWebNavigationPolicy(controller: configuration.userContentController))
    }

    static func extract(html: String, baseURL: URL, readability: String) async throws -> ExtractedContent {
        try Task.checkCancellation()
        let page = makePage()
        return try await parse(html: html, baseURL: baseURL, readability: readability, page: page)
    }

    static func parse(html: String, baseURL: URL, readability: String, page: WebPage) async throws -> ExtractedContent {
        try Task.checkCancellation()
        defer { page.stopLoading() }
        do {
            return try await withTaskCancellationHandler {
                _ = try await ReaderWebContentPolicy.contentRules()
                for try await _ in page.load(html: ReaderWebContentPolicy.blankDocument) { try Task.checkCancellation() }
                try Task.checkCancellation()
                let script = readability + """

                const source = new DOMParser().parseFromString(sourceHTML, 'text/html');
                const parsed = new Readability(source, {charThreshold:0,maxElemsToParse:50000}).parse();
                return parsed ? JSON.stringify({html:parsed.content || '',text:parsed.textContent || ''}) : null;
                """
                let value = try await page.callJavaScript(script, arguments: ["sourceHTML": inertDocument(html: html, baseURL: baseURL)], contentWorld: .defaultClient)
                try Task.checkCancellation()
                guard let json = value as? String else { throw unavailable() }
                let result = try await decode(json)
                let safeHTML = try await ReaderWebContentPolicy.sanitizedHTML(result.html, baseURL: baseURL, page: page)
                return ExtractedContent(html: safeHTML, text: result.text)
            } onCancel: {
                Task { @MainActor [weak page] in page?.stopLoading() }
            }
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    static func inertDocument(html: String, baseURL: URL) -> String {
        let base = baseURL.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!doctype html><html><head>
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; form-action 'none'">
        <base href="\(base)"></head><body>\(html)</body></html>
        """
    }

    @concurrent nonisolated private static func decode(_ json: String) async throws -> ExtractedContent {
        try Task.checkCancellation()
        guard let data = json.data(using: .utf8) else { throw unavailable() }
        struct Result: Decodable { var html: String; var text: String }
        let result = try JSONDecoder().decode(Result.self, from: data)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw unavailable() }
        try Task.checkCancellation()
        return ExtractedContent(html: result.html, text: text)
    }

    nonisolated private static func unavailable() -> ReaderError {
        .unavailable(String(localized: "No article text was found on this page.", bundle: #bundle))
    }
}

/// Applies the same native restrictions to extraction and visible article pages.
@MainActor
public enum ReaderWebContentPolicy {
    public static func configuration(_ original: WebPage.Configuration = WebPage.Configuration()) -> WebPage.Configuration {
        var configuration = original
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController = WKUserContentController()
        configuration.webExtensionController = nil
        configuration.defaultNavigationPreferences.allowsContentJavaScript = false
        configuration.loadsSubresources = false
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.supportsAdaptiveImageGlyph = false
        configuration.deviceSensorAuthorization = .init(decision: .deny)
        return configuration
    }

    private static let compiledRules = Task { @MainActor in
        try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ReaderBlockAllArticleResourcesV1",
            encodedContentRuleList: #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]"#)
    }

    public static func contentRules() async throws -> WKContentRuleList {
        try Task.checkCancellation()
        guard let rules = try await compiledRules.value else { throw ReaderError.invalidResponse }
        try Task.checkCancellation()
        return rules
    }

    public static let blankDocument = """
    <!doctype html><html><head>
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; form-action 'none'; base-uri 'none'">
    </head><body></body></html>
    """

    nonisolated public static func permitsExternalLink(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && !(url.host ?? "").isEmpty && url.user == nil && url.password == nil
    }

    /// Uses WebKit's inert DOM parser, then copies only passive HTML into a clean document.
    public static func sanitizedHTML(_ html: String, baseURL: URL?, page: WebPage) async throws -> String {
        try Task.checkCancellation()
        guard html.utf8.count <= 4_000_000 else { throw ReaderError.invalidResponse }
        do {
            return try await withTaskCancellationHandler {
                _ = try await contentRules()
                for try await _ in page.load(html: blankDocument) { try Task.checkCancellation() }
                let script = #"""
                const source = new DOMParser().parseFromString(sourceHTML, 'text/html');
                if (source.getElementsByTagName('*').length > 50000) throw new Error('Document element limit exceeded');
                const clean = document.implementation.createHTMLDocument('');
                const htmlNamespace = 'http://www.w3.org/1999/xhtml';
                const allowed = new Set(['a','abbr','article','aside','b','bdi','bdo','blockquote','br','caption','cite','code','col','colgroup',
                  'dd','del','dfn','div','dl','dt','em','figcaption','figure','footer','h1','h2','h3','h4','h5','h6','header','hr','i',
                  'kbd','li','main','mark','nav','ol','p','pre','q','rp','rt','ruby','s','samp','section','small','span','strong',
                  'sub','sup','table','tbody','td','tfoot','th','thead','time','tr','u','ul','var','wbr']);
                const removed = new Set(['script','style','link','meta','base','iframe','frame','frameset','object','embed','form','input',
                  'button','select','textarea','option','canvas','svg','math','template','noscript','audio','video','source','track',
                  'applet','marquee','blink','portal','fencedframe','xmp','plaintext']);
                function copy(node, parent) {
                  if (node.nodeType === Node.TEXT_NODE) { parent.appendChild(clean.createTextNode(node.textContent)); return; }
                  if (node.nodeType !== Node.ELEMENT_NODE || node.namespaceURI !== htmlNamespace) return;
                  const name = node.localName.toLowerCase();
                  if (name === 'img') {
                    const alt = node.getAttribute('alt');
                    if (alt) parent.appendChild(clean.createTextNode(alt));
                    return;
                  }
                  if (removed.has(name)) return;
                  if (!allowed.has(name)) { for (const child of Array.from(node.childNodes)) copy(child, parent); return; }
                  const element = clean.createElement(name);
                  const title = node.getAttribute('title'), lang = node.getAttribute('lang'), direction = node.getAttribute('dir');
                  if (title) element.setAttribute('title', title);
                  if (lang) element.setAttribute('lang', lang);
                  if (['ltr','rtl','auto'].includes(direction)) element.setAttribute('dir', direction);
                  const id = node.getAttribute('id');
                  if (id) element.setAttribute('id', 'reader-source-' + id.slice(0, 128));
                  if (name === 'a') {
                    const raw = (node.getAttribute('href') || '').trim();
                    if (raw.startsWith('#')) element.setAttribute('href', '#reader-source-' + raw.slice(1));
                    else {
                      try {
                        const url = new URL(raw, sourceBaseURL || undefined);
                        if (raw && ['https:','http:'].includes(url.protocol) && !url.username && !url.password) element.setAttribute('href', url.href);
                      } catch {}
                    }
                  }
                  if (['td','th','col','colgroup'].includes(name)) {
                    for (const attribute of ['colspan','rowspan','span']) {
                      const value = Number(node.getAttribute(attribute));
                      if (Number.isInteger(value) && value >= 1 && value <= 100) element.setAttribute(attribute, String(value));
                    }
                  }
                  for (const child of Array.from(node.childNodes)) copy(child, element);
                  parent.appendChild(element);
                }
                for (const child of Array.from(source.body.childNodes)) copy(child, clean.body);
                return clean.body.innerHTML;
                """#
                let value = try await page.callJavaScript(script, arguments: ["sourceHTML": html, "sourceBaseURL": baseURL?.absoluteString ?? ""],
                                                          contentWorld: .defaultClient)
                try Task.checkCancellation()
                guard let result = value as? String else { throw ReaderError.invalidResponse }
                return result
            } onCancel: {
                Task { @MainActor [weak page] in page?.stopLoading() }
            }
        } catch {
            try Task.checkCancellation()
            throw ReaderError.invalidResponse
        }
    }
}

@MainActor
public struct ReaderWebNavigationPolicy: WebPage.NavigationDeciding {
    private let openLink: ((URL) -> Void)?
    private let controller: WKUserContentController?
    public init(openLink: ((URL) -> Void)? = nil, controller: WKUserContentController? = nil) {
        self.openLink = openLink
        self.controller = controller
    }

    public func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        preferences.allowsContentJavaScript = false
        if let controller {
            do { controller.add(try await ReaderWebContentPolicy.contentRules()) } catch { return .cancel }
        }
        guard let url = action.request.url else { return .cancel }
        if url.absoluteString.components(separatedBy: "#").first == "about:blank" { return .allow }
        if action.navigationType == .linkActivated, ReaderWebContentPolicy.permitsExternalLink(url) { openLink?(url) }
        return .cancel
    }
}

/// Retains at most the article byte limit and cancels only its own native request.
private final class BoundedArticleDownload: NSObject, URLSessionDataDelegate {
    typealias Value = (Data, HTTPURLResponse)
    private struct State {
        var task: URLSessionDataTask?
        var continuation: CheckedContinuation<Value, any Error>?
        var response: HTTPURLResponse?
        var data = Data()
        var error: (any Error)?
        var cancelled = false
        var redirects = 0
    }
    private let state = Mutex(State())
    private let maximumBytes: Int

    init(maximumBytes: Int) { self.maximumBytes = maximumBytes }

    func start(_ request: URLRequest, session: URLSession, continuation: CheckedContinuation<Value, any Error>) {
        let task = state.withLock { value -> URLSessionDataTask? in
            guard !value.cancelled else { return nil }
            let task = session.dataTask(with: request)
            task.delegate = self
            value.task = task
            value.continuation = continuation
            return task
        }
        if let task { task.resume() } else { continuation.resume(throwing: CancellationError()) }
    }

    func cancel() {
        let task = state.withLock { value in value.cancelled = true; return value.task }
        task?.cancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let accepted = state.withLock { value in
            guard !value.cancelled, value.error == nil else { return false }
            guard let target = request.url, ReaderWebContentPolicy.permitsExternalLink(target),
                  !(response.url?.scheme == "https" && target.scheme == "http"), value.redirects < 5 else {
                value.error = ReaderError.invalidResponse
                return false
            }
            value.redirects += 1
            return true
        }
        completionHandler(accepted ? request : nil)
        if !accepted { task.cancel() }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        let accepted = state.withLock { value in
            guard !value.cancelled, value.error == nil else { return false }
            guard let http = response as? HTTPURLResponse else {
                value.error = ReaderError.invalidResponse
                return false
            }
            guard (200..<300).contains(http.statusCode) else {
                value.error = ReaderError.server(http.statusCode)
                return false
            }
            guard ["text/html", "application/xhtml+xml"].contains(http.mimeType?.lowercased() ?? ""),
                  http.expectedContentLength <= maximumBytes else {
                value.error = ReaderError.invalidResponse
                return false
            }
            value.response = http
            return true
        }
        completionHandler(accepted ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let overflow = state.withLock { value in
            guard !value.cancelled, value.error == nil else { return false }
            guard data.count <= maximumBytes - value.data.count else {
                value.error = ReaderError.invalidResponse
                return true
            }
            value.data.append(data)
            return false
        }
        if overflow { dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let completion = state.withLock { value -> (CheckedContinuation<Value, any Error>?, Result<Value, any Error>) in
            let result: Result<Value, any Error>
            if value.cancelled {
                result = .failure(CancellationError())
            } else if let failure = value.error ?? error {
                result = .failure(failure)
            } else if let response = value.response {
                result = .success((value.data, response))
            } else { result = .failure(ReaderError.invalidResponse) }
            let continuation = value.continuation
            value.continuation = nil
            value.task = nil
            value.data = Data()
            return (continuation, result)
        }
        completion.0?.resume(with: completion.1)
    }
}
