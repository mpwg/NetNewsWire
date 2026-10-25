import Foundation
import Testing
import ReaderContent
import ReaderDomain

struct ContentTests {
    @Test("OPML round trips preserve homepages and folders") func opmlRoundTripsPreserveHomepagesAndFolders() throws {
        let account = UUID()
        let feed = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "feed/1"), title: "Café & Oil",
            url: try #require(URL(string: "https://example.org/rss")), homePageURL: URL(string: "https://example.org"), folderIDs: ["news"])
        let folder = FolderSnapshot(accountID: account, remoteID: "news", title: "Café")
        let parsed = try OPMLDocument.parse(OPMLDocument.export(feeds: [feed], folders: [folder]))
        #expect(parsed.count == 1)
        #expect(parsed.first?.title == feed.title)
        #expect(parsed.first?.homePageURL == feed.homePageURL)
        #expect(parsed.first?.folderPath == ["Café"])
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
    @Test("Complete HTML fragments gain a document and body before Readability", .timeLimit(.minutes(1)),
          arguments: [0, 1, 2, 3])
    func completeFragmentsGainDocumentStructure(kind: Int) async throws {
        let marker = String(repeating: "Fragment article content remains readable. ", count: 40)
        let article = "<article><h1>Fragment article</h1><p>" + marker + "<a href='../offer'>Relative offer</a></p></article>"
        let html: String
        switch kind {
        case 0: html = article
        case 1: html = "<body>" + article + "</body>"
        case 2: html = "<html><head><title>Fragment title</title></head>" + article + "</html>"
        default: html = marker
        }
        let service = ArticleContentService()
        let result = try await service.extract(html: html, baseURL: #require(URL(string: "https://fragment.reader.invalid/articles/source")))
        #expect(result.text.contains("Fragment article content remains readable."))
        if kind != 3 { #expect(result.html.contains("https://fragment.reader.invalid/offer")) }
    }

    @Test("Unrecoverable malformed HTML returns an unavailable-content error", .timeLimit(.minutes(1)),
          arguments: ["<html><body><article><p>Unfinished content", "<html><body></body></html>"])
    func unrecoverableMarkupReportsUnavailable(html: String) async throws {
        let content = ArticleContentService()
        await #expect {
            try await content.extract(html: html, baseURL: #require(URL(string: "https://malformed.reader.invalid/source")))
        } throws: { error in
            guard let error = error as? ReaderError, case .unavailable(let message) = error else { return false }
            return !message.isEmpty
        }
    }

    @Test("Full text is extracted without executing page scripts") func fullTextIsExtractedWithoutExecutingPageScripts() async throws {
        let content = ArticleContentService()
        let html = "<html><head><title>Offers</title></head><body><article><h1>Café for €2.99</h1><p>" + String(repeating: "Fresh coffee from the merchant. ", count: 80) + "<a href='/offer'>View offer</a></p><script>throw new Error('page script must not execute')</script></article></body></html>"
        let result = try await content.extract(html: html, baseURL: #require(URL(string: "https://example.org/deal")))
        #expect(result.text.contains("Café"))
        #expect(!result.text.contains("page script must not execute"))
        #expect(result.html.contains("https://example.org/offer"))
    }
}
