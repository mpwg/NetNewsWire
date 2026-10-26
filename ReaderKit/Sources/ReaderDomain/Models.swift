import Foundation

public struct ArticleKey: Hashable, Codable, Sendable, Identifiable {
    public var accountID: UUID
    public var remoteID: String
    public var id: String { accountID.uuidString + "/" + remoteID }
    public init(accountID: UUID, remoteID: String) { self.accountID = accountID; self.remoteID = remoteID }
}

public struct FeedKey: Hashable, Codable, Sendable, Identifiable {
    public var accountID: UUID
    public var remoteID: String
    public var id: String { accountID.uuidString + "/" + remoteID }
    public init(accountID: UUID, remoteID: String) { self.accountID = accountID; self.remoteID = remoteID }
}

public struct ReaderAccount: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var serverURL: URL
    public var username: String
    public var name: String
    public init(id: UUID = UUID(), serverURL: URL, username: String, name: String = "FreshRSS") {
        self.id = id; self.serverURL = serverURL; self.username = username; self.name = name
    }
}

public struct FeedSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: FeedKey
    public var title: String
    public var url: URL
    public var homePageURL: URL?
    public var folderIDs: [String]
    public init(id: FeedKey, title: String, url: URL, homePageURL: URL? = nil, folderIDs: [String] = []) {
        self.id = id; self.title = title; self.url = url; self.homePageURL = homePageURL; self.folderIDs = folderIDs
    }
}

public struct FolderSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var accountID: UUID
    public var remoteID: String
    public var title: String
    public var id: String { accountID.uuidString + "/" + remoteID }
    public init(accountID: UUID, remoteID: String, title: String) {
        self.accountID = accountID; self.remoteID = remoteID; self.title = title
    }
}

/// Complete original-article counts, including retained originals without a subscription.
/// Folder totals count a feed once per folder; account/library totals count it only once.
public struct ReaderUnreadCounts: Equatable, Sendable {
    public private(set) var byFeed: [FeedKey: Int]
    public private(set) var byFolder: [String: Int] = [:]
    public private(set) var byAccount: [UUID: Int] = [:]
    public private(set) var total = 0

    public init(byFeed: [FeedKey: Int] = [:], feeds: [FeedSnapshot] = []) {
        self.byFeed = byFeed
        for (key, count) in byFeed {
            byAccount[key.accountID, default: 0] += count
            total += count
        }
        var memberships: [FeedKey: Set<String>] = [:]
        for feed in feeds {
            memberships[feed.id, default: []].formUnion(feed.folderIDs)
        }
        for (key, folders) in memberships {
            for remoteID in folders {
                let folderID = FolderSnapshot(accountID: key.accountID, remoteID: remoteID, title: "").id
                byFolder[folderID, default: 0] += byFeed[key, default: 0]
            }
        }
    }
}

public struct ArticleSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: ArticleKey
    public var feedID: String
    public var title: String
    public var html: String
    public var text: String
    public var url: URL?
    public var datePublished: Date?
    public var dateArrived: Date
    public var read: Bool
    public var starred: Bool
    public init(id: ArticleKey, feedID: String, title: String, html: String = "", text: String = "", url: URL? = nil,
                datePublished: Date? = nil, dateArrived: Date = Date(), read: Bool = false, starred: Bool = false) {
        self.id = id; self.feedID = feedID; self.title = title; self.html = html; self.text = text; self.url = url
        self.datePublished = datePublished; self.dateArrived = dateArrived; self.read = read; self.starred = starred
    }
}

public enum FeedMode: String, Codable, CaseIterable, Sendable { case normal, digest }
public struct FeedPreferences: Identifiable, Hashable, Codable, Sendable {
    public var id: FeedKey
    public var mode: FeedMode
    public var timeZoneID: String
    public var cloudAllowed: Bool
    public var importedHomePageURL: URL?
    public var importedFeedURL: URL?
    public var importedFolderPath: [String]
    public init(id: FeedKey, mode: FeedMode = .normal, timeZoneID: String = TimeZone.current.identifier, cloudAllowed: Bool = false,
                importedHomePageURL: URL? = nil, importedFolderPath: [String] = [], importedFeedURL: URL? = nil) {
        self.id = id; self.mode = mode; self.timeZoneID = timeZoneID; self.cloudAllowed = cloudAllowed
        self.importedHomePageURL = importedHomePageURL; self.importedFolderPath = importedFolderPath
        self.importedFeedURL = importedFeedURL
    }
}

public enum StatusField: String, Codable, Sendable { case read, starred }
public struct PendingChange: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var article: ArticleKey
    public var field: StatusField
    public var value: Bool
    public init(id: UUID = UUID(), article: ArticleKey, field: StatusField, value: Bool) {
        self.id = id; self.article = article; self.field = field; self.value = value
    }
}

public struct ArticleQuery: Hashable, Sendable {
    public var accountID: UUID?
    public var folderID: String?
    public var feed: FeedKey?
    public var unreadOnly: Bool
    public var starredOnly: Bool
    public var search: String
    public var offset: Int
    public var limit: Int
    public init(accountID: UUID? = nil, folderID: String? = nil, feed: FeedKey? = nil, unreadOnly: Bool = false, starredOnly: Bool = false,
                search: String = "", offset: Int = 0, limit: Int = 200) {
        self.accountID = accountID; self.folderID = folderID; self.feed = feed; self.unreadOnly = unreadOnly; self.starredOnly = starredOnly
        self.search = search; self.offset = offset; self.limit = limit
    }
}

public struct RefreshSnapshot: Sendable {
    public var accountID: UUID
    public var feeds: [FeedSnapshot]
    public var folders: [FolderSnapshot]
    public var articles: [ArticleSnapshot]
    public var unreadIDs: Set<String>
    public var starredIDs: Set<String>
    public init(accountID: UUID, feeds: [FeedSnapshot], folders: [FolderSnapshot], articles: [ArticleSnapshot], unreadIDs: Set<String>, starredIDs: Set<String>) {
        self.accountID = accountID; self.feeds = feeds; self.folders = folders; self.articles = articles
        self.unreadIDs = unreadIDs; self.starredIDs = starredIDs
    }
}

/// Source-language offer fields. Presence checks do not prove semantic completeness.
public struct DigestOfferFact: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var product: String
    public var merchant: String?
    public var price: String?
    public var conditions: [String]

    public init(id: UUID = UUID(), product: String, merchant: String? = nil, price: String? = nil, conditions: [String] = []) {
        self.id = id; self.product = product; self.merchant = merchant; self.price = price; self.conditions = conditions
    }

    public var quotedValues: [String] { [product] + [merchant, price].compactMap { $0 } + conditions }

    public var hasValidContent: Bool {
        conditions.count <= 8 && Set(conditions).count == conditions.count &&
        quotedValues.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func hasSameFields(as other: DigestOfferFact) -> Bool {
        product == other.product && merchant == other.merchant && price == other.price && conditions == other.conditions
    }
}

/// Original-language excerpts retained before free-text consolidation; not a completeness guarantee.
public struct DigestSourceFacts: Identifiable, Hashable, Codable, Sendable {
    public var source: ArticleKey
    public var excerpts: [String]
    public var offers: [DigestOfferFact]?
    public var id: ArticleKey { source }

    public init(source: ArticleKey, excerpts: [String], offers: [DigestOfferFact]? = nil) {
        self.source = source
        self.excerpts = excerpts
        self.offers = offers
    }

    public var text: String { excerpts.joined(separator: " · ") }

    public var hasValidContent: Bool {
        !excerpts.isEmpty && Set(excerpts).count == excerpts.count &&
        excerpts.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        (offers ?? []).allSatisfy(\.hasValidContent) &&
        Set((offers ?? []).map(\.id)).count == (offers ?? []).count
    }
}

public struct DigestSection: Hashable, Codable, Sendable {
    public var title: String
    public var text: String
    public var sources: [ArticleKey]
    /// Optional so snapshots written before source facts were introduced remain decodable.
    public var sourceFacts: [DigestSourceFacts]?
    public init(title: String, text: String, sources: [ArticleKey], sourceFacts: [DigestSourceFacts]? = nil) {
        self.title = title; self.text = text; self.sources = sources; self.sourceFacts = sourceFacts
    }

    /// Structural content and reference checks; this does not attest the model's factual accuracy.
    public func hasValidContent(referencing sourceKeys: Set<ArticleKey>, allowingOriginalsOnly: Bool = false) -> Bool {
        let normalizedText = (title + " " + text).lowercased()
        return !normalizedText.contains("http://") && !normalizedText.contains("https://") &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sources.isEmpty && sources.allSatisfy(sourceKeys.contains) &&
        Set((sourceFacts ?? []).map(\.source)).count == (sourceFacts ?? []).count &&
        (sourceFacts ?? []).allSatisfy { sources.contains($0.source) && $0.hasValidContent } &&
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (allowingOriginalsOnly && text.isEmpty))
    }
}

public struct DigestSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var revision: UUID
    public var feed: FeedKey
    public var day: Date
    public var timeZoneID: String
    public var sections: [DigestSection]
    public var sources: [ArticleKey]
    public var warning: String?
    public var generatedAt: Date
    public var sourceFingerprint: String
    public init(id: String, revision: UUID = UUID(), feed: FeedKey, day: Date, timeZoneID: String,
                sections: [DigestSection], sources: [ArticleKey], warning: String? = nil, generatedAt: Date = Date(), sourceFingerprint: String = "") {
        self.id = id; self.revision = revision; self.feed = feed; self.day = day; self.timeZoneID = timeZoneID
        self.sections = sections; self.sources = sources; self.warning = warning; self.generatedAt = generatedAt
        self.sourceFingerprint = sourceFingerprint
    }

    /// Originals-only sections require a visible warning; every original must remain referenced.
    public var hasDisplayableContent: Bool {
        let sourceKeys = Set(sources)
        guard !sourceKeys.isEmpty, sourceKeys.count == sources.count,
              sourceKeys.allSatisfy({ $0.accountID == feed.accountID }) else { return false }
        let allowsOriginalsOnly = warning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return sections.allSatisfy { $0.hasValidContent(referencing: sourceKeys, allowingOriginalsOnly: allowsOriginalsOnly) } &&
            Set(sections.flatMap(\.sources)) == sourceKeys
    }
}

public enum ReaderError: Error, LocalizedError, Equatable, Sendable {
    case invalidURL, invalidResponse, unauthorized, unavailable(String), server(Int), staleResult
    public var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "Invalid server URL.", bundle: #bundle)
        case .invalidResponse: String(localized: "The response could not be processed.", bundle: #bundle)
        case .unauthorized: String(localized: "Sign-in failed. Check the API password.", bundle: #bundle)
        case .unavailable(let reason): reason
        case .server(let status): String(localized: "Server error (HTTP \(status)).", bundle: #bundle)
        case .staleResult: String(localized: "This operation was superseded by a newer one.", bundle: #bundle)
        }
    }
}
