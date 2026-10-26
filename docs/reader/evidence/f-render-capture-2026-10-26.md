# F: hosted article text contracts — 2026-10-26

## Owner text-only decision

On 2026-10-26 the owner explicitly stopped OCR work and requested text-only verification. The active four-case Swift Testing contract now reads text directly from the actual hosted ArticleDetailView's WebPage. Vision imports, recognition requests, compute-stage selection, page-image exports and their image/OCR attachments are removed. No further OCR or pixel-analysis variant is planned.

Current text-test source: **6882228f316caa993ad29ecd43111076f432d13e**. Fresh [Reader CI 40285814983](https://github.com/mpwg/NetNewsWire/actions/runs/40285814983) is live; inspect this existing handle for the changed-source text/lifetime cases and full plan result.

For successful extraction the actual document must contain the extracted heading and representative body text. HTTP failure, empty extraction and held cancellation must retain the saved heading and saved body text. Existing request/error/state/outbox checks, cancellation, view removal and weak graph-release assertions remain. No UI method, retry or timing workaround is added. Production rendering, parser isolation and article-resource restrictions are unchanged.

The earlier OCR experiment is superseded by this owner instruction, not accepted as passing. Direct document text does not establish screenshot pixels; historical capture limitations are retained as observations. Existing native UI reading/accessibility and actual offline/restart/platform requirements remain separately scoped. The owner has changed the verification method, not approved unfinished product criteria.

| Current criterion | Status | Evidence |
|---|---|---|
| No OCR or page-image export in active Reader code/tests | Fulfilled | Vision import, recognition/compute calls and image-export/attachment block removed through Xcode MCP. Source search finds no remaining OCR/image-export calls. |
| Saved/extracted heading and body text in actual WebKit document | Open | Direct document-text assertions are implemented for all four existing outcomes; fresh execution is required. |
| Cancellation and weak graph release | Open on changed source | Existing four-case assertions remain; re-execution is required after removal of the OCR experiment. |
| Build and strict lint | Fulfilled | Xcode MCP build-for-testing at 08:23:04 local time succeeds; compiler warnings remain errors. Strict SwiftLint and whitespace checks pass. |
| Held normal Reader | Fulfilled | No local tests or relaunch are performed. |
| Actual offline/restart and final platform/accessibility requirements | Open | Owner-deferred or separately tracked in the main acceptance matrix; text tests do not substitute for them. |

## Historical experiment and preserved failures

Before the owner stopped OCR, the existing actual hosted ArticleDetailView test exported WebKit page images and attempted native text recognition before removal. The experiment added no UI method and changed no production source.

- **f1682366e / Reader CI 40281918990:** 428 passes / four failures of 432, no skips. All four OCR calls throw e5rtError("e5rt_e5_compiler_compile call failed", 11); all ten native methods pass. [Original summary](f-pixels-default-ci-summary-2026-10-26.json), [case nodes](f-pixels-default-ci-cases-2026-10-26.json), [attachment manifest](f-pixels-default-ci-manifest-2026-10-26.json). Artifact 12633311708, ZIP SHA-256 192d63840d0e3917a723bd718fcf96a373eaa419511298a1a35a2d9dbc32afa1.
- **0cd248c0f / Reader CI 40283730920:** the explicitly supported CPU configuration produces the same four OCR errors, plus a separate native VoiceOver snapshot connection failure: 427 passes / five failures of 432, no skips. [Original summary](f-pixels-cpu-ci-summary-2026-10-26.json), [case nodes](f-pixels-cpu-ci-cases-2026-10-26.json). Artifact 12633512419, ZIP SHA-256 dfcef431534c6b1ca8619f3bc93eb1b7ff3d690745daf400048e73d1c4f0921c. No compiler-error cause or native-service repair is established.

The previously inspected original exports remain historical evidence: [success](f-pixels-default-success-2026-10-26.png), [HTTP failure](f-pixels-default-failure-2026-10-26.png), [empty extraction](f-pixels-default-empty-2026-10-26.png), [held cancellation](f-pixels-default-cancelled-2026-10-26.png), [native Starred window](f-pixels-default-native-window-2026-10-26.png). Success/failure/cancelled show expected text; the empty export and native body region are white. These observations are not a complete rendering or lifetime pass. No additional image analysis is required by the active text contract.

The earlier baseline **14d85474e / CI 40280649483** passes 432 executions (422 code, ten native), 217 distinct tests, no failures/skips, with runtime/test/probe source unchanged from 846b16357. [Original summary](b-star-policy-confirmation-summary-2026-10-26.json), [policy/native case nodes](b-star-policy-confirmation-cases-2026-10-26.json). It predates the OCR experiment and the current additional body-text assertions; it is not relabelled as changed-source proof.

## CI trigger scope

Four exact non-runtime README exclusions remain: Reader/README.md and ReaderKit/Sources/{ReaderPersistence,ReaderSync,ReaderUI}/README.md. The package READMEs are explicitly excluded by Package.swift; the app README is outside its synchronized source directory. No resource/fixture pattern is excluded.

Both push and pull_request retain their original positive source/script/workflow paths, followed by exact negative paths according to [GitHub's path-filter documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onpushpull_requestpull_request_targetpathspaths-ignore). Parsed-YAML comparison across every tracked file verifies that only those four documentation paths are excluded; 68 trigger paths remain for each event. Manual macOS/all coverage and all jobs/security checks remain enabled.

Observed main pushes confirm the configuration: functional/workflow push f1682366e starts Reader CI 40281918990; documentation/Reader README receipt 3765df0eb creates only CodeQL 40282086844 and does not start or cancel Reader CI. The PR filter is checked structurally, without claiming a live PR event. CodeQL's separate Swift tracer failure remains open.
