# I: public feed text and selection boundary — 2026-10-26

Status: **Mac selection/store boundary fulfilled on 32dc1126d; model quality and full acceptance open**.

The owner retains free summaries in the app language. Important statements may be selected, but every original must remain linked. This is an end-to-end digest requirement; it does not require model prose to claim evidence from every article.

## Criteria

| Criterion | Status | Evidence |
|---|---|---|
| Permit key-statement selection with exact supporting provenance | Fulfilled on Mac | CI 40314710783 passes the v5 two-account native controlled-model selection contract. |
| Every original remains linked; stored articles/outbox unchanged | Fulfilled on Mac | The new native controlled-model/ReaderStore integration passes in the same run, including complete snapshot/outbox comparisons and explicit originals fallback. |
| Invalid references, numbers, URLs, blank text, budgets and old caches | Fulfilled on Mac | Current v5 native suite passes, including the new v4 cache-upgrade case and unchanged negative validators. |
| Native compilation, lint and README | Fulfilled | Xcode MCP app/test and probe builds, strict lint and whitespace pass. ReaderKit README documents selected prose versus all-original links and bounded corpus input. |
| Representative semantic model quality | Open | Public fixed corpus retains excerpt failures and missing merchants; earlier conditional-fidelity counterexamples remain. |
| PCC and final-platform/device/operational prerequisites | Open | No authorized PCC entitlement or final-device acceptance. Actual offline/persistent-app restart remains owner-deferred. |

## Source evidence and fix

The existing DigestCoordinator already adds unselected originals as a separate originals section, retains every original in the digest source list, and reports incomplete AI coverage. The generator nevertheless rejected valid selections before the coordinator could apply that contract. The first fixed public pair under policy v4 illustrates this: both source fact packets validate, but consolidation selects packet 0 from available packets 0 and 1 and is rejected for incomplete coverage.

Policy v5 removes that contradictory completeness requirement from model instructions and group validation. Returned sections may reference only evidence actually used. Nonempty/in-range references, exact excerpt matching, per-reference numbers, URLs, nonblank content, account identity, budgets, cancellation and cloud authorization remain enforced. No omitted reference is added to model prose. Coordinator fallback, warning/cache-reuse semantics, store schema and UI are unchanged. The new policy fingerprint refreshes v4 and older cards on the next generation request.

Swift Testing adds a native controlled-model/real in-memory ReaderStore integration: one selected article produces the model section plus an originals section for the other article; the digest retains both keys, remains displayable, warns about incomplete AI coverage, and leaves complete article snapshots and the outbox unchanged. The two-account provenance case now accepts a valid selection without assigning the unselected identity to its prose. Existing invalid-reference, borrowed-price and failure contracts remain.

Xcode MCP app/test build-for-testing 12:20:17 and probe build 12:20:27 pass. Strict SwiftLint and git diff --check pass. Discovery reports 235 enabled distinct tests, none disabled; the current-source confirmation below now proves all 478 executions (468 code plus ten unchanged native methods). Reader/My Mac is restored and held normal Reader PID 24529 remains; no local app tests/relaunch occur.

Generator SHA-256: `604700192553e84b886a3a8246f2eb5631f6481745cfee8c96c1d9b57f0e260e`. Probe SHA-256: `8d0a2c1fcdcb5293fb619a6873eb5741e0c166321343d58a3464a803ac527632`.

## Public corpus protocol and limits

The public [Preisjäger RSS feed](https://www.preisjaeger.at/rss/alle) returned HTTP 200 with 30 items on 2026-10-26. The fixed first six items, published 08:45:49–10:19:59 UTC, were chosen before inference, evaluated as one six-item group and three consecutive pairs. Each configuration runs once per policy; failures are retained. Only RSS text is used. No article page, image, subresource, publisher script, FreshRSS account, credential, app store or PCC request is involved. This is not real FreshRSS ingestion or app acceptance.

RSS SHA-256: `fea83b709a7c1877b17322fec1d8626c3c591a88decee96cbb45bd343ac17a21`. The synthetic-account ArticleSnapshot JSON is 19,837 bytes, SHA-256 `8219fcc2380f7181e99a1b70bb1044916f3418519152bd7f91465b3e4fce5d7b`. Its text preparation follows the existing FreshRSS tag/entity/whitespace transformation; input titles/URLs/publication dates are retained, HTML is empty. The probe's new optional --scenario corpus --input PATH accepts at most 512 KiB and 1–32 snapshots. It opens only that explicitly named local file.

Raw third-party inputs and model prose remain local in /tmp/reader-public-preisjaeger-*.json. The [aggregate receipt](i-public-feed-selection-2026-10-26.json) preserves factual source metadata, input/report hashes, errors, times and selection counts without publishing full source prose. Missing IDs in a raw generator report measure model selection coverage; they do not measure missing final digest links.

Under v4 all four runs reject. One pair reaches consolidation with valid facts and selects only its first article; the other three fail exact excerpt validation. One rejected excerpt differs only in letter case; other failures are not case-only. No fuzzy match, numeric normalization or silent source repair is introduced.

Under v5 the first pair produces structurally valid summaries of both originals with the listed prices, but omits merchant names. It is not a semantic acceptance pass. The six-item group and both remaining pairs still fail exact excerpt validation. All eight original observations are accounted for in the aggregate receipt; selected successes do not erase failures or establish a representative quality improvement. Free-summary quality, attached conditions and reliable long inputs remain open.

The aggregate receipt also independently checks literal merchant/price mentions against public RSS attributes for each referenced original. Checks are case-insensitive and include section titles, with no numerical/equivalence normalization; they are narrow omission diagnostics, not a semantic validator or proof that every unselected fact must appear.

## Preceding evaluation-tool CI, preserved before this change

[Reader CI 40309420884](https://github.com/mpwg/NetNewsWire/actions/runs/40309420884), source c9c33ec4e11e8c5a3f6c103301f3246c1b30a544, is terminal failure: 475 passed / one failed execution of 476, 233 passed / one failed distinct test of 234, no skips. All 466 code executions and nine native methods pass. ReaderSmokeTests/testVoiceOverAnnouncesReaderAndMovesFocus() fails after losing the connection to the app/helper. The artifact also captures testmanagerd EXC_BAD_ACCESS/SIGSEGV (faulting thread 7, top frame objc_release). Co-occurrence is evidence of native infrastructure failure, not proof of its exact cause or a product repair. No retry or timeout waiver is used.

[Original summary](i-review-tool-ci-summary-2026-10-26.json), [I/native case nodes](i-review-tool-ci-cases-2026-10-26.json), [process recovery](i-review-tool-ci-recovery-2026-10-26.json). Artifact 12644443365 ZIP SHA-256 `8d26c37aa99ed2d7112bb6107d9df99e93cec8dd2e4952c815e15815624fb058`. Destination arm64 My Mac VM, macOS 27.0.1 (26A434). The full crash report remains in the artifact. Earlier eaf90aea6 / CI 40304336042 is the named all-476 pass; it does not verify policy v5 or erase later native failures.

No package or issue is closed. PCC, final devices, owner-deferred offline/restart, full accessibility/performance/distribution and complete Swift CodeQL remain open independently.

## Current v5 native confirmation

[Reader CI 40314710783](https://github.com/mpwg/NetNewsWire/actions/runs/40314710783) succeeds on **32dc1126d00772350726f9cbb04cdb0c6713025b**: **478/478 executions**, comprising **225 Swift Testing functions in 34 suites / 468 code executions plus ten native methods**. There are 235 distinct tests, no failures or skips. Lint, isolated-probe build, direct runner and process recovery pass. Destination arm64 My Mac VM, macOS 27.0.1 (26A434). Later commits change only documentation/evidence; owning source is unchanged.

[Original summary](i-v5-ci-summary-2026-10-26.json), [I/native case nodes](i-v5-ci-cases-2026-10-26.json), [process recovery](i-v5-ci-recovery-2026-10-26.json). Artifact 12646273462 ZIP SHA-256 `685cb9638714bff7360727427b6c044ffd41156bf3612ea65ce4a28df8cce75a`. The new selection/complete-originals/unchanged-store integration and two-account provenance case pass, as do previous-policy cache refresh, hierarchy and negative checks. This establishes the scoped Mac code boundary, not semantic model quality, a native-service repair or full platform/product acceptance. Earlier VoiceOver/daemon/removal failures remain preserved and unexplained; no unchanged retry was used.
