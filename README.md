# Reader

A native FreshRSS reader for macOS, iOS and iPadOS 27 or later, built with SwiftUI, SwiftData and Apple's Foundation Models. Each feed can show ordinary articles or a sourced daily digest. Originals stay accessible through feeds, search, stars and digest source links.

Open **Reader/Reader.xcodeproj** in Xcode 27 and select the shared **Reader** scheme. Use Xcode MCP for interactive project changes, builds and tests. The project was created with Apple's multiplatform template; no project, scheme or test-plan generator is used.

## Repository

- [Reader](Reader/README.md): native app, assets, unhosted code tests and the small native UI suite.
- [ReaderKit](ReaderKit/README.md): six libraries and the standalone SwiftData recovery probe.
- [Acceptance matrix](docs/reader/acceptance.md): criterion-specific evidence and outstanding product/platform work.
- [Continuation handoff](docs/reader/handoff-2026-10-24.md): current work and owner decisions.
- [Canonical language review](docs/reader/evidence/k-canonical-language-2026-10-26.md): all 43 historical GitHub audit descriptions reviewed, with 28 translated to English and dispositions/evidence preserved.
- scripts/test-reader.sh and scripts/verify-reader-store.py: current CI orchestration.

The original NetNewsWire application, modules, extensions, assets, distribution tools and superseded Reader projects were removed on the owner's instruction. They remain recoverable in Git history. Only the native Reader project is an active application build entry point.

## Accounts and testing

Enable FreshRSS API access and set a separate API password. Enter the HTTPS server, username and API password in Reader. Debug uses eu.mpwg.reader.debug; Release uses eu.mpwg.reader, with separate stores and Keychain services. A development team and provisioning are needed for physical-device execution.

All code-testable app and runner behavior uses **Swift Testing** under Reader/ReaderTests. This includes actual WebKit document checks and native SwiftUI component lifetime tests where app automation is unnecessary. XCTest/XCUIAutomation is reserved for native window, sheet, keyboard, scrolling and visible app behavior. Native HTML5 parsing now replaces the reproduced XML-parser failures. Article downloads fetch only the bounded HTML document; source scripts, publisher CSS, all article images and other resources are blocked during extraction and display. Bundled Readability and Reader's parser code remain trusted JavaScript in an isolated WebKit context. The isolation matrix uses Swift Testing. The current native UI suite has ten methods, including the VoiceOver candidate; runtime status is recorded separately below. See [current content-isolation evidence](docs/reader/evidence/f-active-content-2026-10-25.md) for exact local/hosted status. See the [native rendering evidence](docs/reader/evidence/f-rendering-2026-10-25.md) for exact checkpoints and image-capture limits. Function identifiers use English lowerCamelCase; readable descriptions belong in @Test display names.

Every app, test and ReaderKit target enables Approachable Concurrency and compiler warnings as errors in Debug and Release. The shared scheme uses Apple's automatic test plan. CI first executes the Swift Testing runner contracts directly, then runs the native Reader plan and the process-recovery probe. Automatic coverage focuses on Mac; manual coverage: all retains Mac/iPhone/iPad validation for final acceptance.

The CI results artifact is configured to retain newly generated native Reader/testmanagerd crash reports alongside xcresult and recovery data. This diagnostic collection preserves failures and does not retry or suppress tests. [Collection scope and current verification](docs/reader/evidence/k-accessibility-navigation-2026-10-26.md#native-crash-report-collection).

Full product acceptance remains open. Real network-off/restart, final devices/iPad windows, accessibility, representative model/feed quality, PCC entitlement and distribution retain their explicit requirements. PCC is disabled in the normal build. See [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45) and [cleanup evidence](docs/reader/evidence/k-reader-only-2026-10-25.md).

## Current verification

The [acceptance matrix](docs/reader/acceptance.md) records the exact candidate, CI handles, tested source and open requirements. Passing an earlier checkpoint does not accept the current app. Full product acceptance remains open.

The complete store count query and the aggregation/session revision contracts have Mac runtime proof. The corresponding #26 Reader Mac contract is accepted at 82d5fe870 with a 31-day-old unread subject, unchanged surviving full snapshots and actual native counters after deletion; [original results and scope](docs/reader/evidence/b-unread-counts-2026-10-26.md) preserve the separate failing VoiceOver gate. The corresponding #29 canonical-version contract is accepted on its exercised Mac boundary. [Criteria and original results](docs/reader/evidence/b-canonical-identity-2026-10-26.md). Independent-star/nonempty-subscription retention is proved in store/session/process tests. For #40 the owner chose authoritative complete FreshRSS unread membership, with pending local status precedence preserved; explicit read-policy proof, visible Starred and complete app restart remain open. [Retention evidence](docs/reader/evidence/b-star-retention-2026-10-26.md).

Code tests exercise 1,000/10,000 articles; the single scrolling case measures the normal initial 200-row page. Warm in-memory timings and hosted Debug CPU/memory/hitch samples do not establish representative performance budgets or energy acceptance. [Load criteria and raw observations](docs/reader/evidence/k-load-preparation-2026-10-26.md).

Native VoiceOver has both named passing runs and retained failures; full menu/form/article journeys, initially-on restoration and the earlier daemon fault remain open. The unfiltered accessibility audit retains menu/contrast findings and the basic manual journey is pending. [Actual speech/state/window evidence](docs/reader/evidence/k-accessibility-navigation-2026-10-26.md). Swift CodeQL fails before analysis with a separately documented SDK-27 support gap. All existing security checks remain enabled. [CodeQL evidence](docs/reader/evidence/k-codeql-compatibility-2026-10-25.md).

## Model verification

The current `codex/reader-offer-fields` candidate replaces copied offer values with bounded references to original words/punctuation. Main remains v10. All250 candidate Mac code functions /551 executions pass; actual model quality remains pending. [Current reference criteria](docs/reader/evidence/i-offer-references-v11-2026-10-26.md). Earlier typed-copy failures below remain historical evidence.

The separate typed-offer candidate retains per-offer product, merchant, price/discount and condition records beside free summaries. Unknown values point to the original. All246 final Mac code functions /534 executions pass, but all four fixed public configurations reject rewritten fields; it is not accepted for integration. [Complete typed-offer criteria and original results](docs/reader/evidence/i-offer-fields-v9-2026-10-26.md). Source copying and semantic quality remain open; the v7 receipt below remains the verified baseline.

Foundation Models uses structured sessions with source references tied to stored article identities. Validation rejects generated links, unsupported numeric claims and blank content. Literal duplicate sentences/sections are removed without merging distinct source identities. New results, existing cache reuse and startup publication share content/source rules: invalid cards cannot hide originals, and originals-only cards require an explicit warning. Model and presentation-state contracts use Swift Testing; actual UI interactions remain separate.

The owner-approved multi-stage pipeline now retains original-language source facts alongside free app-language summaries. Source quotations stay tied to each original through consolidation and are checked before publication/cache reuse. The detail view displays selectable plain text with an explicit incomplete-terms notice. Historical digests remain readable; policy v7 regenerates older caches on the next request without changing article/read/outbox state.

[Current source-facts criteria and model observations](docs/reader/evidence/i-source-facts-v7-2026-10-26.md): Reader CI40368691661 passes505 executions (495 code, ten native),244 distinct, no failures/skips. Two of four frozen public configurations return sections with recovered offer terms; two reject altered quotations. Compactness and representative semantic quality remain open. A separate sentence-selection candidate is not integrated because its fixed samples still omit conditions and alter selected claims, despite511 passing code executions. [Complete rejected-candidate evidence](docs/reader/evidence/i-source-selection-v8-2026-10-26.md). [Earlier I evidence](docs/reader/evidence/i-generator-2026-10-25.md) retains reproduced failures. PCC requires approved Apple entitlement/provisioning and is disabled in this build. Full product acceptance remains open.

## OPML acceptance

OPML verification includes actual FreshRSS imports, repeated imports, confirmed folder renames, visible rejection and restoration of the isolated test account. Export follows current category membership while retaining matching imported hierarchy. A folderless repeat preserves an existing assignment. New subscriptions appear only after their complete initial refresh succeeds; confirmed existing feeds can merge import metadata without HTTP. H is accepted for this exercised Mac/server contract: Reader CI 40227398927 passes all 333 executions, including three forced initial-refresh failures. See [H evidence](docs/reader/evidence/h-opml-2026-10-25.md) for the exact scope, owner decisions, original audit distinction and raw evidence. Full product acceptance remains open.

## Attribution

This fork retains NetNewsWire's [MIT license and copyright notice](LICENSE). Local extraction uses pinned Mozilla Readability with its Apache-2.0 notice in ReaderKit/Sources/ReaderContent/Resources. English is the source language; German belongs in localization resources and explicit translation fixtures.
