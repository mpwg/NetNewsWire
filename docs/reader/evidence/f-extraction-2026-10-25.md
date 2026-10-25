# F / #51: extraction publication and ownership — 2026-10-25

## First stable code checkpoint

Eight new Swift Testing functions / sixteen executions exercise the shipping ReaderSession, ArticleContentService, real ReaderStore and isolated URLSession transport. The first fourteen-case run reproduces eight failures: old success can cache after selection changes, A→B→A accepts old error/success, older requests alter newer outcomes, and pre-cancelled/in-flight cancellation surfaces an alert. [Raw initial result](f-extraction-red-2026-10-25.json), original 16-24-46. Two additional contracts verify independent detail-lookup generations and full-text error/retry state.

ReaderSession now distinguishes selection generations from detail lookup and extraction request generations. It validates the current request/selection/cancellation before caching, after the awaited atomic save and before publishing errors. Current success and HTTP failure still publish; status/outbox state remains untouched. A persistent, localized warning identifies saved feed content when full text is unavailable; changing selection or retrying clears only that extraction warning.

The ArticleDetailView button now starts a view-owned task through task(id:), rather than an unstructured Task. Disappearance cancels extraction and explicitly stops WebPage resource loading. WebPage errors check cancellation and article identity before presentation. Source ownership has changed; actual native disappearance/page release remains a separate required check.

The final native Mac plan for this first checkpoint passes **142 Swift Testing functions plus six UI methods / 243 executions**, 148 distinct tests, 36 parameterized functions / 131 cases, no failures/skips/runtime warnings. [Raw current result](f-extraction-core-native-2026-10-25.json), original `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.25_16-29-43-+0100.xcresult`. Strict SwiftLint and diff checks pass. Xcode authoring/build/tests use Xcode MCP; compiler/concurrency policy remains enabled.

## Criteria and next evidence

| Criterion | Status | Evidence or next check |
|---|---|---|
| Current and stale extraction publication | Fulfilled in the controlled HTTP cases | Late success/failure, A→B→A, overlapping requests including a newer failure, current outcomes and same-selection detail lookup. Add the audit's precise after-parsing/before-delivery gate next. |
| Cancellation and graph release | Fulfilled in code; native view lifetime open | Before-request/in-flight cancellation ends while HTTP remains held, without cached content/revisions/alerts. Weak references to session, services, content, store, server and transport disappear after success/failure/cancellation. Native disappearance and actual WebPage lifetime need their own evidence. |
| Restricted source coverage | Implemented and code-verified | Current HTTP failure records a warning; changing selection/retry clears it. Native saved-content/warning rendering is still open. English source text and German catalog translation are present. |
| Parser/network/offline/rendering | Open beyond existing contracts | Existing parser/403/timeout/relative-link/stale-store checks remain; add malformed/varied native content and exact lifecycle evidence. The actual Mac network-off run remains deferred by the owner. |
| Hosted confirmation and final platforms | Open | Await hosted verification of the final F checkpoint; iPhone/iPad/accessibility remain deferred, physical devices need signing. |

F and mapped #33/#34 remain open. This first checkpoint is neither complete F acceptance nor proof of a post-decoding gate, native page deallocation or actual offline operation.
