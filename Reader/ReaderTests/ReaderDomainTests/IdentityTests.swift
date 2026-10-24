import Foundation
import Testing
@testable import ReaderDomain
@testable import ReaderUI

struct IdentityTests {
    @Test("Article identity is scoped to the account") func articleIdentityIsScopedToTheAccount() {
        #expect(ArticleKey(accountID: UUID(), remoteID: "1") != ArticleKey(accountID: UUID(), remoteID: "1"))
    }
    @Test("New changes have distinct acknowledgement identities") func newChangesHaveDistinctAcknowledgementIdentities() {
        let key = ArticleKey(accountID: UUID(), remoteID: "1")
        #expect(PendingChange(article: key, field: .read, value: true).id != PendingChange(article: key, field: .read, value: false).id)
    }
}

// German strings below are intentional expected translations from the compiled catalogs.
struct LocalizationTests {
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
