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

[Reader CI 40259657192](https://github.com/mpwg/NetNewsWire/actions/runs/40259657192) passes at **24d81f8cf**: all **405 executions (395 code, ten native UI)**, 208 distinct tests, zero failures/skips and one deliberate guardrail warning. Actual VoiceOver table entry/forward navigation announces articles 299 and 298 and restores the initially disabled mode. Lint, runner contracts and 10,000-article process recovery pass. [Raw summary, speech/state, inspected window and scope](docs/reader/evidence/k-accessibility-navigation-2026-10-26.md).

The repeat at documentation-only 185675f95 (Reader CI 40262371415) passes all 395 code executions and nine UI methods but fails the fixed first-row title assertion: table-entry speech is clipped, while forward navigation announces complete adjacent titles 298 and 297. The next test candidate requires those two complete titles; Xcode MCP build-for-testing and strict lint pass, with fresh runtime verification pending. Both original results are retained in the linked evidence. This proves neither complete VoiceOver-only menu/form/article journeys, the initially enabled branch nor repair of the earlier native daemon crash. A physical-Mac comparison still awaits owner coordination; the normal Reader remains untouched.

The previous complete green workload checkpoint ee2cefe14 passes all 404 executions in [Reader CI 40247859999](https://github.com/mpwg/NetNewsWire/actions/runs/40247859999). Code tests cover 1,000/10,000 articles; the single scrolling case measures the normal initial 200-row page. Warm in-memory timings, hosted Debug CPU/memory/hitch samples and stable captured geometry establish no representative performance budget or energy acceptance. [Load criteria and raw observations](docs/reader/evidence/k-load-preparation-2026-10-26.md).

Full accessibility remains open despite verified native navigation-role/header corrections. The unfiltered audit retains menu, contrast and other findings; a basic manual VoiceOver journey is pending. Swift CodeQL also fails before analysis and has a separately documented SDK-27 support gap. All existing security checks remain enabled. [CodeQL evidence](docs/reader/evidence/k-codeql-compatibility-2026-10-25.md).

## Model verification

Foundation Models uses structured sessions with source references tied to stored article identities. Validation rejects generated links, unsupported numeric claims and blank content. Literal duplicate sentences/sections are removed without merging distinct source identities. New results, existing cache reuse and startup publication share content/source rules: invalid cards cannot hide originals, and originals-only cards require an explicit warning. Model and presentation-state contracts use Swift Testing; actual UI interactions remain separate.

[I evidence](docs/reader/evidence/i-generator-2026-10-25.md) retains reproduced failures and real local observations. German offer generation and semantic long-text quality remain unresolved; the multi-stage pipeline decision is pending. PCC requires approved Apple entitlement/provisioning and is disabled in this build. Full product acceptance remains open.

## OPML acceptance

OPML verification includes actual FreshRSS imports, repeated imports, confirmed folder renames, visible rejection and restoration of the isolated test account. Export follows current category membership while retaining matching imported hierarchy. A folderless repeat preserves an existing assignment. New subscriptions appear only after their complete initial refresh succeeds; confirmed existing feeds can merge import metadata without HTTP. H is accepted for this exercised Mac/server contract: Reader CI 40227398927 passes all 333 executions, including three forced initial-refresh failures. See [H evidence](docs/reader/evidence/h-opml-2026-10-25.md) for the exact scope, owner decisions, original audit distinction and raw evidence. Full product acceptance remains open.

## Attribution

This fork retains NetNewsWire's [MIT license and copyright notice](LICENSE). Local extraction uses pinned Mozilla Readability with its Apache-2.0 notice in ReaderKit/Sources/ReaderContent/Resources. English is the source language; German belongs in localization resources and explicit translation fixtures.
