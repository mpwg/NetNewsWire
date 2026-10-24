import Foundation
import Testing
@testable import ReaderDomain

struct IdentityTests {
    @Test("Article identity is scoped to the account") func articleIdentityIsScopedToTheAccount() {
        #expect(ArticleKey(accountID: UUID(), remoteID: "1") != ArticleKey(accountID: UUID(), remoteID: "1"))
    }
    @Test("New changes have distinct acknowledgement identities") func newChangesHaveDistinctAcknowledgementIdentities() {
        let key = ArticleKey(accountID: UUID(), remoteID: "1")
        #expect(PendingChange(article: key, field: .read, value: true).id != PendingChange(article: key, field: .read, value: false).id)
    }
}
