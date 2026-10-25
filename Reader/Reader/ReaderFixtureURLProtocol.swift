#if DEBUG && os(macOS)
import Foundation
import Synchronization
import ReaderDomain

/// URLProtocol's legacy callback boundary is protected by Mutex; request work stays off MainActor.
nonisolated final class ReaderFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Int, String, Data)
    static let handler = Mutex<Handler?>(nil)
    private struct State { var task: Task<Void, Never>?; var stopped = false }
    private let state = Mutex(State())

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.handler.withLock { $0 }
        let capturedRequest = request
        let task = Task { @Sendable [self, handler, capturedRequest] in
            do {
                guard let handler, let url = capturedRequest.url else { throw ReaderError.invalidURL }
                let (status, mime, data) = try await handler(capturedRequest)
                try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                                     headerFields: ["Content-Type": mime]) else { throw ReaderError.invalidResponse }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        state.withLock {
            if $0.stopped { task.cancel() } else { $0.task = task }
        }
    }

    override func stopLoading() {
        state.withLock { $0.stopped = true; $0.task?.cancel(); $0.task = nil }
    }
}
#endif
