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

## Source-bound digests

A daily digest keeps links to every original and does not mark articles read when opened. Summaries use the app language; source excerpts remain literal and are validated against their own stored article or feed revision. Unclear merchant, price and conditions are explicitly directed to the original. Source quotations do not prove that a generated claim is correct or that all conditions are present.

Reader rejects recognized item-condition upgrades and the documented omitted evening weekday. If a generated section fails those checks, independently permitted sections remain and affected originals are shown with a warning. If a source-fact response contains an unowned quotation, all staged facts for that original are discarded; other originals remain eligible. Model request errors and cancellation still propagate. These checks are bounded safeguards, not general semantic validation. [Fact-isolation criteria](docs/reader/evidence/i-fact-isolation-2026-10-27.md) · [Partial-section criteria](docs/reader/evidence/i-partial-guarded-sections-2026-10-27.md).

An isolated FreshRSS test account returned 30 public-feed articles and was restored after inspection. Separate local-model samples retain every original and leave article/outbox state unchanged. The latest six-source public-text run produced four free sections and two originals-only sources, but omitted a distinguishing product variant and offer restrictions; its source-fact blocks were not compact. Reliable offer attribution, conditions and representative summary quality remain open. [Real-feed scope](docs/reader/evidence/i-live-feed-ingestion-2026-10-27.md) · [Current model observation](docs/reader/evidence/i-fact-isolation-2026-10-27.md).

## Accounts and testing

Enable FreshRSS API access and set a separate API password. Enter the HTTPS server, username and API password in Reader. Debug uses eu.mpwg.reader.debug; Release uses eu.mpwg.reader, with separate stores and Keychain services. A development team and provisioning are needed for physical-device execution.

All code-testable app and runner behavior uses **Swift Testing** under Reader/ReaderTests. This includes actual WebKit document checks and native SwiftUI component lifetime tests where app automation is unnecessary. XCTest/XCUIAutomation is reserved for native window, sheet, keyboard, scrolling and visible app behavior. Native HTML5 parsing now replaces the reproduced XML-parser failures. Article downloads fetch only the bounded HTML document; source scripts, publisher CSS, all article images and other resources are blocked during extraction and display. Bundled Readability and Reader's parser code remain trusted JavaScript in an isolated WebKit context. The isolation matrix uses Swift Testing. The current native UI suite has eleven methods, including the VoiceOver candidate; runtime status is recorded separately below. See [current content-isolation evidence](docs/reader/evidence/f-active-content-2026-10-25.md) for exact local/hosted status. See the [text-only native rendering evidence](docs/reader/evidence/f-render-capture-2026-10-26.md) for exact checkpoints. Function identifiers use English lowerCamelCase; readable descriptions belong in @Test display names.

Article redirects reject HTTPS-to-HTTP downgrades regardless of scheme casing. The [redirect checkpoint](docs/reader/evidence/f-redirect-policy-2026-10-26.md) distinguishes policy tests from actual HTTP transport evidence and records the untested TLS boundary.

Every app, test and ReaderKit target enables Approachable Concurrency and compiler warnings as errors in Debug and Release. The shared scheme uses Apple's automatic test plan. CI first executes the Swift Testing runner contracts directly, then runs the native Reader plan and the process-recovery probe. Automatic coverage focuses on Mac; manual coverage: all retains Mac/iPhone/iPad validation for final acceptance.

The CI results artifact is configured to retain newly generated native Reader/testmanagerd crash reports alongside xcresult and recovery data. This diagnostic collection preserves failures and does not retry or suppress tests. [Collection scope and current verification](docs/reader/evidence/k-accessibility-navigation-2026-10-26.md#native-crash-report-collection).

Full product acceptance remains open. Real network-off/restart, final devices/iPad windows, accessibility, representative model/feed quality, PCC entitlement and distribution retain their explicit requirements. PCC is disabled in the normal build. See [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45) and [cleanup evidence](docs/reader/evidence/k-reader-only-2026-10-25.md).

## Current verification

The [acceptance matrix](docs/reader/acceptance.md) records the exact candidate, CI handles, tested source and open requirements. Passing an earlier checkpoint does not accept the current app. Full product acceptance remains open.

The complete store count query and the aggregation/session revision contracts have Mac runtime proof. The corresponding #26 Reader Mac contract is accepted at 82d5fe870 with a 31-day-old unread subject, unchanged surviving full snapshots and actual native counters after deletion; [original results and scope](docs/reader/evidence/b-unread-counts-2026-10-26.md) preserve the separate failing VoiceOver gate. The corresponding #29 canonical-version contract is accepted on its exercised Mac boundary. [Criteria and original results](docs/reader/evidence/b-canonical-identity-2026-10-26.md). Independent-star/nonempty-subscription retention is proved in store/session/process tests. For #40 the owner chose authoritative complete FreshRSS unread membership, with pending local status precedence preserved; read-policy and visible Starred have the documented Mac proof; a complete app restart remains open. [Retention evidence](docs/reader/evidence/b-star-retention-2026-10-26.md).

Code tests exercise 1,000/10,000 articles; the single scrolling case measures the normal initial 200-row page. Warm in-memory timings and hosted Debug CPU/memory/hitch samples do not establish representative performance budgets or energy acceptance. [Load criteria and raw observations](docs/reader/evidence/k-load-preparation-2026-10-26.md).

Native VoiceOver has both named passing runs and retained failures; full menu/form/article journeys, initially-on restoration and the earlier daemon fault remain open. The unfiltered accessibility audit retains menu/contrast findings and the basic manual journey is pending. [Actual speech/state/window evidence](docs/reader/evidence/k-accessibility-navigation-2026-10-26.md). Swift CodeQL fails before analysis with a separately documented SDK-27 support gap. All existing security checks remain enabled. [CodeQL evidence](docs/reader/evidence/k-codeql-compatibility-2026-10-25.md).

## Model verification

Reader uses bounded, staged source-fact extraction and consolidation. Source ownership, unsupported numbers and generated links are checked before publication; the same source and safety checks apply to cached digests. A warning accompanies originals-only results. The on-device model is the default. Apple Private Cloud Compute is disabled until its entitlement and provisioning are approved and separately verified.

The owner chose conservative local field attribution: display a merchant, price or condition only when its association is supported, and show “See original” for unclear details. Field-specific attribution and a compact complete facts line are not yet established. An exact source quotation alone does not prove its semantic role. Historical model experiments and their failed outcomes remain available through the [acceptance matrix](docs/reader/acceptance.md#i--54-current-generation-and-acceptance-boundary); no earlier green test is a substitute for current model-quality acceptance.

## OPML acceptance

OPML verification includes actual FreshRSS imports, repeated imports, confirmed folder renames, visible rejection and restoration of the isolated test account. Export follows current category membership while retaining matching imported hierarchy. A folderless repeat preserves an existing assignment. New subscriptions appear only after their complete initial refresh succeeds; confirmed existing feeds can merge import metadata without HTTP. H is accepted for this exercised Mac/server contract: Reader CI 40227398927 passes all 333 executions, including three forced initial-refresh failures. See [H evidence](docs/reader/evidence/h-opml-2026-10-25.md) for the exact scope, owner decisions, original audit distinction and raw evidence. Full product acceptance remains open.

## Attribution

This fork retains NetNewsWire's [MIT license and copyright notice](LICENSE). Local extraction uses pinned Mozilla Readability with its Apache-2.0 notice in ReaderKit/Sources/ReaderContent/Resources. English is the source language; German belongs in localization resources and explicit translation fixtures.
