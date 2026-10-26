# K: canonical English issue descriptions — 2026-10-26

The owner requires English code and documentation; German belongs in translations or explicitly captured language fixtures. Reader guides and implementation work packages already use English, but inspection found German canonical descriptions in the earlier GitHub audit inventory. This follow-up now completes individual language review of all 43 historical audit/recommendation/report descriptions #2–#44: 28 translated titles/bodies and 15 already English. This is scoped language verification, not product acceptance or a claim about every historical discussion.

## Verified descriptions

| Issue | Current English title | Language action | Preserved disposition |
|---|---|---|---|
| [#2](https://github.com/mpwg/NetNewsWire/issues/2) | Author migration treats database errors as completion and deletes legacy data | Title and full body translated | Closed, not planned |
| [#3](https://github.com/mpwg/NetNewsWire/issues/3) | Cooperative author migration overwrites authors from intervening feed updates | Title and full body translated | Closed, not planned |
| [#4](https://github.com/mpwg/NetNewsWire/issues/4) | CloudKit acknowledges real partial failures and drops pending status changes | Title and full body translated | Closed, not planned |
| [#5](https://github.com/mpwg/NetNewsWire/issues/5) | Status queues need serialization and revision-bound acknowledgements | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#6](https://github.com/mpwg/NetNewsWire/issues/6) | Feed settings migration cannot resume after interruption | Title and full body translated | Closed, not planned |
| [#7](https://github.com/mpwg/NetNewsWire/issues/7) | Widget refresh misses changes to total counts | Title and full body translated | Closed, not planned |
| [#8](https://github.com/mpwg/NetNewsWire/issues/8) | XML format detection bypasses parser encoding and namespace support | Title and full body translated | Closed, not planned |
| [#9](https://github.com/mpwg/NetNewsWire/issues/9) | Atom processing discards valid prefixed article fields | Title and full body translated | Closed, not planned |
| [#10](https://github.com/mpwg/NetNewsWire/issues/10) | Metadata parsing and image scaling execute synchronously on the UI actor | Already English; reviewed | Open; remaining requirements unchanged |
| [#11](https://github.com/mpwg/NetNewsWire/issues/11) | A global serial parser queue couples independent feed refreshes | Title and full body translated | Closed, not planned |
| [#12](https://github.com/mpwg/NetNewsWire/issues/12) | macOS feed switching waits synchronously for the entire timeline query | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#13](https://github.com/mpwg/NetNewsWire/issues/13) | macOS sharing reports success before the URL is resolved and saved | Title and full body translated | Closed, not planned |
| [#14](https://github.com/mpwg/NetNewsWire/issues/14) | The macOS Share extension reads the wrong App Group in Debug builds | Title and full body translated | Closed, not planned |
| [#15](https://github.com/mpwg/NetNewsWire/issues/15) | Local build-and-test scripts omit iOS tests despite reporting success | Title and full body translated | Open; remaining requirements unchanged |
| [#16](https://github.com/mpwg/NetNewsWire/issues/16) | Strong back references retain removed accounts and refreshers | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#17](https://github.com/mpwg/NetNewsWire/issues/17) | Refresh completion does not await parsing, persistence and status enqueue | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#18](https://github.com/mpwg/NetNewsWire/issues/18) | Optimistic CloudKit folder deletion loses feed references before remote reconciliation | Title and full body translated | Closed, not planned |
| [#19](https://github.com/mpwg/NetNewsWire/issues/19) | Removing a CloudKit folder copy deletes data for a feed that remains subscribed | Title and full body translated | Closed, not planned |
| [#20](https://github.com/mpwg/NetNewsWire/issues/20) | Initial CloudKit sync retains only the first folder of a feed with multiple memberships | Title and full body translated | Closed, not planned |
| [#21](https://github.com/mpwg/NetNewsWire/issues/21) | ReaderAPI swallows feed-name and folder-membership mutation errors | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#22](https://github.com/mpwg/NetNewsWire/issues/22) | ReaderAPI marks articles read before authoritative status retrieval succeeds | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#23](https://github.com/mpwg/NetNewsWire/issues/23) | Feedly treats a failed fetch attempt as a successful watermark | Title and full body translated | Closed, not planned |
| [#24](https://github.com/mpwg/NetNewsWire/issues/24) | Feedly acknowledges content updates despite a truncated article download | Title and full body translated | Closed, not planned |
| [#25](https://github.com/mpwg/NetNewsWire/issues/25) | ReaderAPI and NewsBlur folder reconciliation ignores empty memberships | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#26](https://github.com/mpwg/NetNewsWire/issues/26) | Deletion-only article changes do not update the timeline and unread counts | Title and full body translated | Open; remaining requirements unchanged |
| [#27](https://github.com/mpwg/NetNewsWire/issues/27) | The CloudKit receive operation loses errors at the async boundary | Title and full body translated | Closed, not planned |
| [#28](https://github.com/mpwg/NetNewsWire/issues/28) | CloudKit cleanup deletes further batches after cancellation and overwrites the cancelled state | Title and full body translated | Closed, not planned |
| [#29](https://github.com/mpwg/NetNewsWire/issues/29) | Multiple versions of one article ID produce inconsistent database and cache states | Title and full body translated | Open; remaining requirements unchanged |
| [#30](https://github.com/mpwg/NetNewsWire/issues/30) | Synchronous retry delays block the UI actor during credential access | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#31](https://github.com/mpwg/NetNewsWire/issues/31) | An unused public URL helper returns the prefix when asked to remove it | Title and full body translated | Closed, not planned |
| [#32](https://github.com/mpwg/NetNewsWire/issues/32) | CloudKitSync and NewsBlur have only placeholder tests outside the central test plan | Title and full body translated | Closed, not planned |
| [#33](https://github.com/mpwg/NetNewsWire/issues/33) | Reader results are not bound to their request and current article selection | Already English; reviewed | Open; remaining requirements unchanged |
| [#34](https://github.com/mpwg/NetNewsWire/issues/34) | ArticleExtractor retains its UI delegates in a permanent ownership cycle | Already English; reviewed | Open; remaining requirements unchanged |
| [#35](https://github.com/mpwg/NetNewsWire/issues/35) | Theme replacement deletes the existing package before the new import succeeds | Title and full body translated | Closed, not planned |
| [#36](https://github.com/mpwg/NetNewsWire/issues/36) | The Share extension and Today widget bypass the existing localization structure | Title and full body translated | Closed, not planned |
| [#37](https://github.com/mpwg/NetNewsWire/issues/37) | Independent favicon fallback depends on homepage metadata success | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#38](https://github.com/mpwg/NetNewsWire/issues/38) | Interleaved homepage favicon jobs share mutable completion state | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#39](https://github.com/mpwg/NetNewsWire/issues/39) | OPML import loses parsed homepage URLs at the account boundary | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#40](https://github.com/mpwg/NetNewsWire/issues/40) | Startup cleanup deletes stars from unsubscribed feeds contrary to the retention contract | Title and full body translated | Open; remaining requirements unchanged |
| [#41](https://github.com/mpwg/NetNewsWire/issues/41) | iOS timeline synchronously fetches all feed articles while building a context menu | Already English; reviewed | Open; remaining requirements unchanged |
| [#42](https://github.com/mpwg/NetNewsWire/issues/42) | Shared state model and incremental SwiftUI app for macOS and iOS | Title and full body translated | Closed, not planned |
| [#43](https://github.com/mpwg/NetNewsWire/issues/43) | Assess upstream PRs and issue inventory as an integration and migration basis | Title and full body translated | Closed, completed report |
| [#44](https://github.com/mpwg/NetNewsWire/issues/44) | Completion report: 40 findings, architecture decision, upstream comparison and review gaps | Title and full body translated | Closed, completed report |

All 43 receive a dated clarification linking owner-authorized source retirement at e61b2fa26. The stale retained-legacy statement in #10 is corrected; replacement evidence and remaining platform requirements are unchanged. The original audit/reassessment remains historical: exclusion is not repair, earlier static evidence is not a runtime reproduction, and later deletion is not acceptance of unfinished Reader requirements. Already-English replacement evidence remains verbatim. Open #15/#26/#29/#40 retain their original requirements; translating them creates no acceptance. Reports #43/#44 remain completed reports, and #42 remains superseded/not planned. Their upstream counts, historical checks and recommendations are explicitly dated; no new upstream review is claimed. The #44 index uses the current English canonical titles.

Before each update the live issue title/body was compared with the reviewed snapshot. Every original URL, inline code identifier and fenced runtime-output block was verified present in the replacement body. Fenced output is checked separately from inline code so that translated surrounding prose cannot be mistaken for a code identifier. The update response was checked for the exact intended title/body and unchanged state/state reason. No labels, assignees, milestone or state fields were submitted. Historical source references remain pinned to 7e17aec6406263378f788812d452859016fcd1ed; no current source repair, migration, service call or new test result is asserted by a translation.

## Verification and limits

- Every description in #2–#44 is individually reviewed and its update response verified. [Per-issue receipt](k-canonical-language-receipt-2026-10-26.json) records counts, dispositions and preservation checks. Dependabot PR #1 is already English and is left unchanged.
- Preserve dated findings, original code links, acceptance limits and later disposition. Do not reopen or close an issue as a side effect of language work.
- All 43 historical descriptions are reviewed, with 28 translated. This does not claim that every historical comment, third-party quoted source or remote GitHub document is English.

README and the acceptance/handoff documents link the completed description inventory. No app, test, build configuration or CI source changes in this language-only step. The active native VoiceOver diagnostic run remains independent; all accessibility, platform, model-quality and service requirements keep their existing status.
