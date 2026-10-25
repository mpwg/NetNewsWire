import Foundation
import ImageIO
import Synchronization
import ReaderDomain

/// Coalesces requests per homepage and bounds network concurrency, response sizes and memory.
/// The returned bytes can be decoded by the caller using its own display-scale context.
public actor IconService {
    private struct Job {
        let id: UUID
        let task: Task<Data?, any Error>
        var consumers: Set<UUID>
    }
    private struct Cached { let data: Data; let created: Date }
    private let session: URLSession
    private let permits: IconPermits
    private let maximumBytes: Int
    private var jobs: [URL: Job] = [:]
    private var cache: [URL: Cached] = [:]

    public init(session: URLSession = .shared, maximumConcurrentRequests: Int = 3, maximumBytes: Int = 1_048_576) {
        self.session = session
        self.permits = IconPermits(limit: max(1, maximumConcurrentRequests))
        self.maximumBytes = max(1, maximumBytes)
    }

    public func icon(for homePage: URL) async throws -> Data? {
        try Task.checkCancellation()
        guard let key = Self.normalized(homePage) else { throw ReaderError.invalidURL }
        if let cached = cache[key], Date().timeIntervalSince(cached.created) < 86_400 { return cached.data }
        let consumer = UUID()
        let job: Job
        if var existing = jobs[key] {
            existing.consumers.insert(consumer)
            jobs[key] = existing
            job = existing
        } else {
            let session = session
            let maximumBytes = maximumBytes
            let permits = permits
            let task = Task {
                await permits.acquire()
                do {
                    try Task.checkCancellation()
                    let data = try await Self.load(key, session: session, maximumBytes: maximumBytes)
                    await permits.release()
                    return data
                } catch {
                    await permits.release()
                    throw error
                }
            }
            job = Job(id: UUID(), task: task, consumers: [consumer])
            jobs[key] = job
        }
        return try await withTaskCancellationHandler {
            defer { releaseConsumer(consumer, for: key, jobID: job.id) }
            let data = try await job.task.value
            try Task.checkCancellation()
            if let data {
                if cache.count >= 32, let oldest = cache.min(by: { $0.value.created < $1.value.created })?.key { cache[oldest] = nil }
                cache[key] = Cached(data: data, created: Date())
            }
            return data
        } onCancel: {
            Task { await self.releaseConsumer(consumer, for: key, jobID: job.id) }
        }
    }

    private func releaseConsumer(_ consumer: UUID, for homePage: URL, jobID: UUID) {
        guard var job = jobs[homePage], job.id == jobID else { return }
        job.consumers.remove(consumer)
        if job.consumers.isEmpty {
            job.task.cancel()
            jobs[homePage] = nil
        } else { jobs[homePage] = job }
    }

    fileprivate func discardCachedIcon(for homePage: URL) {
        if let key = Self.normalized(homePage) { cache[key] = nil }
    }

    fileprivate static func normalized(_ url: URL) -> URL? {
        guard ["https", "http"].contains(url.scheme?.lowercased()), url.host != nil,
              url.user == nil, url.password == nil,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.fragment = nil
        return parts.url
    }

    private static func load(_ homePage: URL, session: URLSession, maximumBytes: Int) async throws -> Data? {
        var candidates: [URL] = []
        do {
            let (data, response) = try await fetch(homePage, session: session, maximumBytes: min(maximumBytes, 524_288), image: false)
            if let html = String(data: data, encoding: .utf8) {
                candidates = iconCandidates(in: html, relativeTo: response.url ?? homePage)
            }
        } catch {
            try Task.checkCancellation()
            // The host-level fallback is independent of homepage download or metadata success.
        }
        if var root = URLComponents(url: homePage, resolvingAgainstBaseURL: false) {
            root.path = "/favicon.ico"
            root.query = nil
            root.fragment = nil
            if let url = root.url, !candidates.contains(url) { candidates.append(url) }
        }
        for candidate in candidates {
            try Task.checkCancellation()
            do {
                let (data, _) = try await fetch(candidate, session: session, maximumBytes: maximumBytes, image: true)
                if !data.isEmpty { return data }
            } catch { try Task.checkCancellation() }
        }
        return nil
    }

    static func iconCandidates(in html: String, relativeTo base: URL) -> [URL] {
        guard let attributes = try? NSRegularExpression(pattern: "([\\w-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", options: [.caseInsensitive]) else { return [] }
        var result: [URL] = []
        for tag in HTMLHeadLinks.scan(html) {
            let link = String(tag)
            var values: [String: String] = [:]
            for attribute in attributes.matches(in: link, range: NSRange(link.startIndex..., in: link)) {
                guard let name = Range(attribute.range(at: 1), in: link),
                      let value = (2...4).compactMap({ Range(attribute.range(at: $0), in: link) }).first else { continue }
                values[String(link[name]).lowercased()] = String(link[value])
            }
            let rels = Set((values["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
            guard !rels.isDisjoint(with: ["icon", "apple-touch-icon", "apple-touch-icon-precomposed"]),
                  let href = values["href"]?.replacingOccurrences(of: "&amp;", with: "&"),
                  let url = URL(string: href, relativeTo: base)?.absoluteURL,
                  let normalized = normalized(url), !result.contains(normalized) else { continue }
            result.append(normalized)
        }
        return result
    }

    private static func fetch(_ url: URL, session: URLSession, maximumBytes: Int, image: Bool) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(image ? "image/*" : "text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let download = BoundedIconDownload(maximumBytes: maximumBytes, image: image)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                download.start(request, session: session, continuation: continuation)
            }
        } onCancel: { download.cancel() }
    }
}

/// Decodes bounded thumbnails on its own actor, never on the UI actor.
public actor FeedImageService {
    private struct Key: Hashable { let url: URL; let pixels: Int }
    private struct Cached { let image: CGImage; let created: Date }
    private let icons: IconService
    private var cache: [Key: Cached] = [:]

    public init(icons: IconService = IconService()) { self.icons = icons }

    public func image(for homePage: URL, maximumPixelSize: Int) async throws -> CGImage? {
        try Task.checkCancellation()
        guard let url = IconService.normalized(homePage) else { throw ReaderError.invalidURL }
        let pixels = min(256, max(1, maximumPixelSize))
        let key = Key(url: url, pixels: pixels)
        if let image = cachedImage(for: key) { return image }
        guard let data = try await icons.icon(for: url) else { return nil }
        try Task.checkCancellation()
        // Another consumer may have decoded the same pixels while this request awaited bytes.
        if let image = cachedImage(for: key) { return image }
        guard let image = Self.thumbnail(data, pixels: pixels) else {
            // Malformed image bytes must not prevent a later network retry.
            await icons.discardCachedIcon(for: url)
            return nil
        }
        try Task.checkCancellation()
        if cache.count >= 32, let oldest = cache.min(by: { $0.value.created < $1.value.created })?.key {
            cache[oldest] = nil
        }
        cache[key] = Cached(image: image, created: Date())
        return image
    }

    private func cachedImage(for key: Key) -> CGImage? {
        guard let cached = cache[key], Date().timeIntervalSince(cached.created) < 86_400 else { return nil }
        return cached.image
    }

    private static func thumbnail(_ data: Data, pixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData,
                                                       [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// Owns one bounded native task and releases its task and continuation on completion.
private final class BoundedIconDownload: NSObject, URLSessionDataDelegate {
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
    private let image: Bool

    init(maximumBytes: Int, image: Bool) { self.maximumBytes = maximumBytes; self.image = image }

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
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                value.error = ReaderError.invalidResponse
                return false
            }
            let mime = http.mimeType?.lowercased() ?? ""
            guard image ? mime.hasPrefix("image/") : ["text/html", "application/xhtml+xml"].contains(mime) else {
                value.error = ReaderError.invalidResponse
                return false
            }
            guard http.expectedContentLength <= maximumBytes else {
                value.error = ReaderError.unavailable(String(localized: "The icon is too large.", bundle: #bundle))
                return false
            }
            value.response = http
            return true
        }
        completionHandler(accepted ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let tooLarge = state.withLock { value in
            guard !value.cancelled, value.error == nil else { return false }
            guard data.count <= maximumBytes - value.data.count else {
                value.error = ReaderError.unavailable(String(localized: "The icon is too large.", bundle: #bundle))
                return true
            }
            value.data.append(data)
            return false
        }
        if tooLarge { dataTask.cancel() }
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

/// A bounded metadata tokenizer, not a document renderer. Stops before body content.
private enum HTMLHeadLinks {
    private static let headElements: Set<String> = [
        "html", "head", "base", "basefont", "bgsound", "link", "meta", "title", "noframes", "style", "script", "noscript"
    ]

    static func scan(_ html: String) -> [Substring] {
        var cursor = html.startIndex
        var links: [Substring] = []
        var templateDepth = 0
        while cursor < html.endIndex, let opening = html[cursor...].firstIndex(of: "<") {
            if templateDepth == 0, html[cursor..<opening].contains(where: { !$0.isWhitespace && $0 != "\u{feff}" }) { return links }
            if html[opening...].hasPrefix("<!--") {
                guard let closing = html.range(of: "-->", range: opening..<html.endIndex) else { return links }
                cursor = closing.upperBound
                continue
            }
            guard let end = endOfTag(in: html, after: opening) else { return links }
            let content = html[html.index(after: opening)..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            let closing = content.hasPrefix("/")
            let name = content.dropFirst(closing ? 1 : 0).prefix { $0.isLetter || $0.isNumber || $0 == "-" }.lowercased()
            cursor = html.index(after: end)
            if name == "template" {
                templateDepth = max(0, templateDepth + (closing ? -1 : 1))
                continue
            }
            if templateDepth == 0 {
                if closing && ["head", "body", "html", "br"].contains(name) { return links }
                if !closing, !name.isEmpty, !headElements.contains(name) { return links }
                if name == "link", !closing { links.append(html[opening...end]) }
            }
            if !closing, ["script", "style", "title", "noframes", "textarea"].contains(name) {
                guard let closingTag = html.range(of: "</" + name + "(?=[\\s/>])",
                                                  options: [.regularExpression, .caseInsensitive],
                                                  range: cursor..<html.endIndex) else { return links }
                cursor = closingTag.lowerBound
            }
        }
        return links
    }

    private static func endOfTag(in html: String, after opening: String.Index) -> String.Index? {
        var cursor = html.index(after: opening)
        var quote: Character?
        while cursor < html.endIndex {
            let character = html[cursor]
            if let currentQuote = quote {
                if character == currentQuote { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" { return cursor }
            cursor = html.index(after: cursor)
        }
        return nil
    }
}

private actor IconPermits {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(limit: Int) { available = limit }
    func acquire() async {
        if available > 0 { available -= 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        if waiters.isEmpty { available += 1 } else { waiters.removeFirst().resume() }
    }
}
