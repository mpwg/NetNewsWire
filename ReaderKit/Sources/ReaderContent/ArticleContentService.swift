import Foundation
import JavaScriptCore
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

/// Runs the vendored Mozilla parser in a private JS context, without executing page scripts.
public actor ArticleContentService: ArticleContentExtracting {
    private let session: URLSession
    public init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        self.session = session ?? URLSession(configuration: configuration)
    }

    public func extract(url: URL) async throws -> ExtractedContent {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { throw ReaderError.invalidURL }
        try Task.checkCancellation()
        let download = BoundedArticleDownload(maximumBytes: 4_000_000)
        let (data, response) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                download.start(URLRequest(url: url), session: session, continuation: continuation)
            }
        } onCancel: { download.cancel() }
        try Task.checkCancellation()
        guard data.count <= 4_000_000,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ReaderError.invalidResponse
        }
        let result = try extract(html: html, baseURL: response.url ?? url)
        return result
    }

    public func extract(html: String, baseURL: URL) throws -> ExtractedContent {
        try Task.checkCancellation()
        guard html.utf8.count <= 4_000_000, let context = JSContext() else { throw ReaderError.invalidResponse }
        // JavaScriptCore has no browser URL constructor. Resolve links with Foundation instead.
        let resolve: @convention(block) (String, String) -> String = { raw, base in
            let url = URL(string: raw, relativeTo: URL(string: base))?.absoluteURL
            return url?.scheme == nil ? "" : (url?.absoluteString ?? "")
        }
        context.setObject(resolve, forKeyedSubscript: "readerResolveURL" as NSString)
        context.evaluateScript("class URL { constructor(raw, base) { this.href = readerResolveURL(String(raw), base ? String(base) : ''); if (!this.href) throw new Error('Invalid URL'); } }")
        for name in ["JSDOMParser", "Readability"] {
            guard let path = Bundle.module.url(forResource: name, withExtension: "js") else {
                throw ReaderError.unavailable(String(localized: "The local full-text parser is missing.", bundle: #bundle))
            }
            context.evaluateScript(try String(contentsOf: path, encoding: .utf8))
            guard context.exception == nil else { throw ReaderError.invalidResponse }
        }
        context.setObject(html, forKeyedSubscript: "sourceHTML" as NSString)
        context.setObject(baseURL.absoluteString, forKeyedSubscript: "sourceURL" as NSString)
        let script = """
        (function () {
          const doc = new JSDOMParser().parse(sourceHTML);
          if (!doc.documentElement) {
            const root = doc.createElement('html');
            for (const child of Array.from(doc.childNodes)) root.appendChild(child);
            doc.appendChild(root);
            doc.documentElement = root;
          }
          if (!doc.body) {
            const body = doc.createElement('body');
            for (const child of Array.from(doc.documentElement.childNodes)) {
              if (child !== doc.head) body.appendChild(child);
            }
            doc.documentElement.appendChild(body);
            doc.body = body;
          }
          doc.documentURI = sourceURL;
          const parsed = new Readability(doc, {charThreshold: 0, maxElemsToParse: 50000}).parse();
          return parsed ? JSON.stringify({html: parsed.content || '', text: parsed.textContent || ''}) : null;
        })()
        """
        guard let value = context.evaluateScript(script), context.exception == nil else { throw ReaderError.invalidResponse }
        guard !value.isNull, !value.isUndefined else {
            throw ReaderError.unavailable(String(localized: "No article text was found on this page.", bundle: #bundle))
        }
        guard let json = value.toString(), let data = json.data(using: .utf8) else { throw ReaderError.invalidResponse }
        struct Result: Decodable { var html: String; var text: String }
        let result = try JSONDecoder().decode(Result.self, from: data)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ReaderError.unavailable(String(localized: "No article text was found on this page.", bundle: #bundle)) }
        try Task.checkCancellation()
        return ExtractedContent(html: result.html, text: text)
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

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        let accepted = state.withLock { value in
            guard !value.cancelled else { return false }
            guard let http = response as? HTTPURLResponse else {
                value.error = ReaderError.invalidResponse
                return false
            }
            guard (200..<300).contains(http.statusCode) else {
                value.error = ReaderError.server(http.statusCode)
                return false
            }
            guard http.expectedContentLength <= maximumBytes else {
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
