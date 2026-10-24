import Foundation
import Testing
import ReaderContent
import ReaderDomain

struct ContentTests {
    @Test("OPML round trips preserve homepages and folders") func opmlRoundTripsPreserveHomepagesAndFolders() throws {
        let account = UUID()
        let feed = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "feed/1"), title: "Café & Öl",
            url: try #require(URL(string: "https://example.org/rss")), homePageURL: URL(string: "https://example.org"), folderIDs: ["news"])
        let folder = FolderSnapshot(accountID: account, remoteID: "news", title: "Österreich")
        let parsed = try OPMLDocument.parse(OPMLDocument.export(feeds: [feed], folders: [folder]))
        #expect(parsed.count == 1)
        #expect(parsed.first?.title == feed.title)
        #expect(parsed.first?.homePageURL == feed.homePageURL)
        #expect(parsed.first?.folderPath == ["Österreich"])
    }
    @Test("Invalid OPML is rejected", arguments: ["<opml><body>", "<rss/>", "<opml><body><outline xmlUrl='file:///private'/></body></opml>"])
    func invalidOPMLIsRejected(xml: String) {
        #expect(throws: (any Error).self) { try OPMLDocument.parse(Data(xml.utf8)) }
    }
    @Test("Nested folders with matching names remain distinct during export") func nestedFoldersWithMatchingNamesRemainDistinctDuringExport() throws {
        let account = UUID()
        let first = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "a"), title: "A", url: try #require(URL(string: "https://a.example/rss")))
        let second = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "b"), title: "B", url: try #require(URL(string: "https://b.example/rss")))
        let prefs = [FeedPreferences(id: first.id, importedFolderPath: ["A", "News"]), FeedPreferences(id: second.id, importedFolderPath: ["B", "News"])]
        let subscriptions = try OPMLDocument.parse(OPMLDocument.export(feeds: [first, second], folders: [], preferences: prefs))
        #expect(subscriptions.map(\.folderPath) == [["A", "News"], ["B", "News"]])
    }
    @Test("Full text is extracted without executing page scripts") func fullTextIsExtractedWithoutExecutingPageScripts() async throws {
        let content = ArticleContentService()
        let html = "<html><head><title>Offers</title></head><body><article><h1>Café um 2,99 €</h1><p>" + String(repeating: "Frische Café beim Händler. ", count: 80) + "<a href='/angebot'>View offer</a></p><script>throw new Error('page script must not execute')</script></article></body></html>"
        let result = try await content.extract(html: html, baseURL: #require(URL(string: "https://example.org/deal")))
        #expect(result.text.contains("Café"))
        #expect(!result.text.contains("page script must not execute"))
        #expect(result.html.contains("https://example.org/angebot"))
    }
}
