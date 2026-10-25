import Foundation
import Observation
import ReaderDomain
import ReaderSync
import ReaderContent
import ReaderIntelligence

/// Shared work belongs to the account services; selection and presentation belong to a window.
@MainActor @Observable
public final class ReaderServices {
    public let repository: any ReaderRepository
    public let credentials: (any CredentialStore)?
    public let client: FreshRSSClient?
    public let digests: DigestCoordinator?
    public let content: ArticleContentService?
    public let images: FeedImageService
    public let privateCloudComputeConfigured: Bool
    public private(set) var revision = 0
    @ObservationIgnored private var refreshWaiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    var refreshWaiterCount: Int { refreshWaiters.count }
    @ObservationIgnored private var lastSuccessfulRefresh: Date?

    public init(repository: any ReaderRepository, credentials: (any CredentialStore)? = nil,
                client: FreshRSSClient? = nil, digests: DigestCoordinator? = nil, content: ArticleContentService? = nil,
                privateCloudComputeConfigured: Bool = false, images: FeedImageService = FeedImageService()) {
        self.repository = repository
        self.credentials = credentials
        self.client = client
        self.digests = digests
        self.content = content
        self.images = images
        self.privateCloudComputeConfigured = privateCloudComputeConfigured
    }

    public func didChange() { revision &+= 1 }

    /// Cancelling a window releases only its waiter; accepted account work remains service-owned.
    public func refreshIfNeeded(force: Bool = false) async throws {
        try Task.checkCancellation()
        guard let client else { return }
        let id = UUID()
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                    if refreshTask == nil, !force, let lastSuccessfulRefresh,
                       Date().timeIntervalSince(lastSuccessfulRefresh) < 60 {
                        continuation.resume()
                        return
                    }
                    refreshWaiters[id] = continuation
                    guard refreshTask == nil else { return }
                    let repository = repository
                    refreshTask = Task {
                        do {
                            for account in try await repository.accounts() { try await client.refresh(account: account) }
                            finishRefresh(.success(()))
                        } catch {
                            finishRefresh(.failure(error))
                        }
                    }
                }
            } onCancel: {
                Task { @MainActor [weak self] in self?.cancelRefreshWaiter(id) }
            }
        } catch {
            try Task.checkCancellation()
            throw error
        }
        try Task.checkCancellation()
    }

    private func cancelRefreshWaiter(_ id: UUID) {
        refreshWaiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func finishRefresh(_ result: Result<Void, any Error>) {
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        refreshTask = nil
        if case .success = result {
            lastSuccessfulRefresh = Date()
            didChange()
        }
        for continuation in waiters.values { continuation.resume(with: result) }
    }
}

public enum TimelineSelection: Hashable, Sendable {
    case article(ArticleKey)
    case digest(String)
}

public struct TimelineRow: Identifiable, Hashable, Sendable {
    public var id: TimelineSelection
    public var feed: FeedKey
    public var title: String
    public var subtitle: String
    public var date: Date
    public var unread: Bool
    public var starred: Bool
    public var isDigest: Bool
}
