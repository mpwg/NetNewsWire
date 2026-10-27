import Foundation
import Testing
@testable import ReaderDomain
@testable import ReaderUI

struct IdentityTests {
    @Test("Hierarchical counts deduplicate memberships and retain orphan originals",
          arguments: [false, true])
    func unreadCountsPreserveAccountAndFolderIdentity(includesCounts: Bool) throws {
        let account = UUID()
        let foreign = UUID()
        let feedKey = FeedKey(accountID: account, remoteID: "feed/1")
        let foreignKey = FeedKey(accountID: foreign, remoteID: "feed/1")
        let orphanKey = FeedKey(accountID: account, remoteID: "removed")
        let url = try #require(URL(string: "https://example.invalid"))
        let feed = FeedSnapshot(id: feedKey, title: "Feed", url: url, folderIDs: ["one", "one", "two"])
        let duplicate = FeedSnapshot(id: feedKey, title: "Duplicate", url: url, folderIDs: ["two"])
        let foreignFeed = FeedSnapshot(id: foreignKey, title: "Foreign", url: url, folderIDs: ["one"])
        let raw = includesCounts ? [feedKey: 3, foreignKey: 5, orphanKey: 7] : [:]
        let counts = ReaderUnreadCounts(byFeed: raw, feeds: [feed, duplicate, foreignFeed])
        #expect(counts.byFeed == raw)
        #expect(counts.total == (includesCounts ? 15 : 0))
        #expect(counts.byAccount == (includesCounts ? [account: 10, foreign: 5] : [:]))
        #expect(counts.byFolder[FolderSnapshot(accountID: account, remoteID: "one", title: "").id] == (includesCounts ? 3 : 0))
        #expect(counts.byFolder[FolderSnapshot(accountID: account, remoteID: "two", title: "").id] == (includesCounts ? 3 : 0))
        #expect(counts.byFolder[FolderSnapshot(accountID: foreign, remoteID: "one", title: "").id] == (includesCounts ? 5 : 0))
        #expect(ReaderUnreadCounts().total == 0)
    }
    @Test("Article identity is scoped to the account") func articleIdentityIsScopedToTheAccount() {
        #expect(ArticleKey(accountID: UUID(), remoteID: "1") != ArticleKey(accountID: UUID(), remoteID: "1"))
    }
    @Test("New changes have distinct acknowledgement identities") func newChangesHaveDistinctAcknowledgementIdentities() {
        let key = ArticleKey(accountID: UUID(), remoteID: "1")
        #expect(PendingChange(article: key, field: .read, value: true).id != PendingChange(article: key, field: .read, value: false).id)
    }
}

struct DigestSourceFactsTests {
    @Test("Historical digest sections decode without source facts")
    func historicalSectionsRemainReadable() throws {
        let data = Data(#"{"title":"Offer","text":"Original summary.","sources":[{"accountID":"99999999-9999-4999-8999-999999999999","remoteID":"offer"}]}"#.utf8)
        let section = try JSONDecoder().decode(DigestSection.self, from: data)
        #expect(section.sourceFacts == nil)
        #expect(section.text == "Original summary.")
        #expect(section.hasValidContent(referencing: Set(section.sources)))
    }

    @Test("Feed quotations round-trip exactly and old fact snapshots remain readable")
    func feedQuotationRoundTripsAndOldFactsDecode() throws {
        let key = ArticleKey(accountID: UUID(), remoteID: "offer")
        let facts = DigestSourceFacts(source: key, excerpts: ["Full text."], feedExcerpt: "Café · EUR 3,30")
        let data = try JSONEncoder().encode(facts)
        let decoded = try JSONDecoder().decode(DigestSourceFacts.self, from: data)
        #expect(decoded == facts)
        #expect(Data(try #require(decoded.feedExcerpt).utf8) == Data("Café · EUR 3,30".utf8))
        var historical = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        historical.removeValue(forKey: "feedExcerpt")
        let old = try JSONDecoder().decode(DigestSourceFacts.self, from: JSONSerialization.data(withJSONObject: historical))
        #expect(old.feedExcerpt == nil)
        #expect(old.hasValidContent)
        for invalid in ["", "  ", String(repeating: "x", count: 257)] {
            #expect(!DigestSourceFacts(source: key, excerpts: ["Full text."], feedExcerpt: invalid).hasValidContent)
        }
    }

    @Test("Source facts round-trip exact merchant, currency, coupon, exclusion and expiry text")
    func sourceFactsRoundTripWithoutRewriting() throws {
        let key = ArticleKey(accountID: UUID(), remoteID: "offer")
        let excerpts = ["Example Store: EUR 29.99; code SAVE5.", "Until 31 October; not valid for TravelDeals.", "Shipping is not included."]
        let facts = DigestSourceFacts(source: key, excerpts: excerpts)
        let section = DigestSection(title: "Offer", text: "Free summary in the app language.", sources: [key], sourceFacts: [facts])
        let decoded = try JSONDecoder().decode(DigestSection.self, from: JSONEncoder().encode(section))
        #expect(decoded == section)
        #expect(decoded.sourceFacts?.first?.excerpts == excerpts)
        #expect(facts.text == excerpts.joined(separator: " · "))
        #expect(decoded.hasValidContent(referencing: [key]))
    }

    @Test("Empty, duplicate and foreign source fact blocks cannot become displayable", arguments: 0..<6)
    func malformedSourceFactsAreRejected(kind: Int) {
        let key = ArticleKey(accountID: UUID(), remoteID: "offer")
        let foreign = ArticleKey(accountID: UUID(), remoteID: "offer")
        let facts: [DigestSourceFacts]
        switch kind {
        case 0: facts = [DigestSourceFacts(source: foreign, excerpts: ["Foreign offer."])]
        case 1: facts = [DigestSourceFacts(source: key, excerpts: [])]
        case 2: facts = [DigestSourceFacts(source: key, excerpts: [" \n\t"])]
        case 3: facts = [DigestSourceFacts(source: key, excerpts: ["Same.", "Same."])]
        case 4: facts = Array(repeating: DigestSourceFacts(source: key, excerpts: ["Offer."]), count: 2)
        default: facts = [DigestSourceFacts(source: ArticleKey(accountID: key.accountID, remoteID: "other"), excerpts: ["Other offer."])]
        }
        let section = DigestSection(title: "Offer", text: "Summary.", sources: [key], sourceFacts: facts)
        #expect(!section.hasValidContent(referencing: [key, foreign]))
    }
}

// German strings below are intentional expected translations from the compiled catalogs.
struct LocalizationTests {
    @Test("Source fact headings use the requested resource language", arguments: [
        ("en", "Source facts"),
        ("de", "Fakten aus der Quelle")
    ])
    func sourceFactsUseRequestedLanguage(localeID: String, expected: String) {
        var resource = LocalizedStringResource.sourceFacts
        resource.locale = Locale(identifier: localeID)
        #expect(String(localized: resource) == expected)
    }

    @Test("Error resources use the requested language", arguments: [
        ("en", "Invalid server URL."),
        ("de", "Ungültige Serveradresse.")
    ])
    func errorResourcesUseRequestedLanguage(localeID: String, expected: String) {
        var resource = LocalizedStringResource.invalidServerUrl
        resource.locale = Locale(identifier: localeID)
        #expect(String(localized: resource) == expected)
    }

    @Test("Localized status errors preserve the HTTP status", arguments: [
        ("en", "Server error (HTTP 503)."),
        ("de", "Serverfehler (HTTP 503).")
    ])
    func statusErrorsPreserveHTTPStatus(localeID: String, expected: String) {
        var resource = LocalizedStringResource.serverErrorHttp(503)
        resource.locale = Locale(identifier: localeID)
        #expect(String(localized: resource) == expected)
    }

    @Test("Original article counts use localized singular and plural forms", arguments: [
        ("en", 0, "0 original articles"),
        ("en", 1, "1 original article"),
        ("en", 2, "2 original articles"),
        ("de", 0, "0 Originalbeiträge"),
        ("de", 1, "1 Originalbeitrag"),
        ("de", 2, "2 Originalbeiträge")
    ])
    func articleCountsUseLocalizedPluralForms(localeID: String, count: Int, expected: String) {
        var resource = LocalizedStringResource.originalArticles(count)
        resource.locale = Locale(identifier: localeID)
        #expect(String(localized: resource) == expected)
    }
}
