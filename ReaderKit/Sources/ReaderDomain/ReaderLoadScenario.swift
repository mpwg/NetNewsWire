#if DEBUG
import Foundation

/// Synthetic, credential-free data shared by native load probes and their code contracts.
public struct ReaderLoadScenario: Sendable {
    public let account: ReaderAccount
    public let snapshot: RefreshSnapshot

    public static func make(articleCount: Int = 10_000) throws -> ReaderLoadScenario {
        guard articleCount > 0, articleCount <= 10_000,
              let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000045"),
              let serverURL = URL(string: "https://load.reader.invalid") else { throw ReaderError.invalidResponse }
        let account = ReaderAccount(id: accountID, serverURL: serverURL, username: "load-fixture", name: "Load fixture")
        let folders = (0..<10).map {
            FolderSnapshot(accountID: accountID, remoteID: "folder/\($0)", title: "Load folder \($0)")
        }
        let feeds = (0..<100).map { index in
            FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/\(index)"),
                         title: "Load feed \(index)", url: serverURL.appending(path: "feeds/\(index)"),
                         folderIDs: index < 20 ? [] : [folders[(index - 20) % folders.count].remoteID])
        }
        let paragraph = String(repeating: "This synthetic article exercises local reader storage, filtering and presentation without network access. ", count: 12)
        var articles: [ArticleSnapshot] = []
        var unread: Set<String> = []
        var starred: Set<String> = []
        articles.reserveCapacity(articleCount)
        for index in 0..<articleCount {
            let feedIndex = index % feeds.count
            let localIndex = index / feeds.count
            let remoteID = "item/\(index)"
            let isUnread = (localIndex + feedIndex) % 4 != 0
            let isStarred = (localIndex * 3 + feedIndex * 7) % 17 == 0
            let title = "Load article \(index)"
            let text = "\(title). \(paragraph)" + (index % 37 == 0 ? " Search marker: load-needle." : "")
            let date = Date(timeIntervalSince1970: 1_792_800_000 - Double(index) * 60)
            articles.append(ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: remoteID),
                                            feedID: feeds[feedIndex].id.remoteID, title: title,
                                            html: "<article><h1>\(title)</h1><p>\(text)</p></article>", text: text,
                                            url: serverURL.appending(path: "articles/\(index)"),
                                            datePublished: date, dateArrived: date, read: !isUnread, starred: isStarred))
            if isUnread { unread.insert(remoteID) }
            if isStarred { starred.insert(remoteID) }
        }
        return ReaderLoadScenario(account: account,
                                  snapshot: RefreshSnapshot(accountID: accountID, feeds: feeds, folders: folders,
                                                            articles: articles, unreadIDs: unread, starredIDs: starred))
    }
}
#endif
