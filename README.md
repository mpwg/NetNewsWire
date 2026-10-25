# Reader

K load preparation adds an isolated Mac-Debug 10,000-article/100-feed/ten-folder entry and one parameterized Swift Testing workload contract; no UI method is added. Build and strict lint pass. An initial test incorrectly assumes an unbounded repository read; its bounded-page correction passes in Reader CI 40245263068 at faaefe391 (403 executions: 395 code, eight UI; zero failures/skips). Actual first-frame, latency/scroll/memory/energy acceptance remains open. The normal Reader is restored for the pending manual VoiceOver journey. [Scope, original fixture failure and required measurements](docs/reader/evidence/k-load-preparation-2026-10-26.md).

K native navigation/header checkpoint **f43e3094e** is confirmed locally and by [Reader CI 40243128791](https://github.com/mpwg/NetNewsWire/actions/runs/40243128791): **401 executions (393 code, eight unchanged UI), 205 distinct tests, zero failures/skips**, with one deliberate guardrail runtime warning retained. Native button roles and the localized header description remove six Unknown role and two header-description reports. Strict lint, runner propagation and 10,000-article recovery pass. Menu/contrast audit findings and real VoiceOver remain open; the manual basic journey is pending. [Current criteria and raw evidence](docs/reader/evidence/k-accessibility-navigation-2026-10-26.md).

Swift CodeQL remains an open acceptance gate. The current job fails before analysis; its runner and the vendor's separate SDK-27 support limits are documented in [K's compatibility evidence](docs/reader/evidence/k-codeql-compatibility-2026-10-25.md). Existing checks remain enabled. Reader's passing native CI does not establish successful Swift security analysis.

Native Mac OPML file export is accepted at **071a7aee7**. [Reader CI 40237736169](https://github.com/mpwg/NetNewsWire/actions/runs/40237736169) passes **392 executions: 384 Swift Testing code executions and eight native UI methods**, with no failures/skips, plus lint, runner failure propagation and process recovery. The standard Save panel writes the exact chosen OPML filename using user-selected Read/Write and the imported OPML type; App Sandbox remains enabled. One intentional model-guardrail runtime warning is retained. #53's native export follow-up and the earlier H server contract are accepted; full product acceptance remains open. The owner-selected complete-initial-refresh publication policy is unchanged. [Criteria and raw evidence](docs/reader/evidence/h-file-export-2026-10-25.md).

A native FreshRSS reader for macOS, iOS and iPadOS 27 or later, built with SwiftUI, SwiftData and Apple's Foundation Models. Each feed can show ordinary articles or a sourced daily digest. Originals stay accessible through feeds, search, stars and digest source links.

Open **Reader/Reader.xcodeproj** in Xcode 27 and select the shared **Reader** scheme. Use Xcode MCP for interactive project changes, builds and tests. The project was created with Apple's multiplatform template; no project, scheme or test-plan generator is used.

## Repository

- [Reader](Reader/README.md): native app, assets, unhosted code tests and the small native UI suite.
- [ReaderKit](ReaderKit/README.md): six libraries and the standalone SwiftData recovery probe.
- [Acceptance matrix](docs/reader/acceptance.md): criterion-specific evidence and outstanding product/platform work.
- [Continuation handoff](docs/reader/handoff-2026-10-24.md): current work and owner decisions.
- scripts/test-reader.sh and scripts/verify-reader-store.py: current CI orchestration.

The original NetNewsWire application, modules, extensions, assets, distribution tools and superseded Reader projects were removed on the owner's instruction. They remain recoverable in Git history. Only the native Reader project is an active application build entry point.

## Accounts and testing

Enable FreshRSS API access and set a separate API password. Enter the HTTPS server, username and API password in Reader. Debug uses eu.mpwg.reader.debug; Release uses eu.mpwg.reader, with separate stores and Keychain services. A development team and provisioning are needed for physical-device execution.

All code-testable app and runner behavior uses **Swift Testing** under Reader/ReaderTests. This includes actual WebKit document checks and native SwiftUI component lifetime tests where app automation is unnecessary. XCTest/XCUIAutomation is reserved for native window, sheet, keyboard, scrolling and visible app behavior. Native HTML5 parsing now replaces the reproduced XML-parser failures. Article downloads fetch only the bounded HTML document; source scripts, publisher CSS, all article images and other resources are blocked during extraction and display. Bundled Readability and Reader's parser code remain trusted JavaScript in an isolated WebKit context. The new isolation matrix uses Swift Testing; the seven existing app UI methods remain unchanged. See [current content-isolation evidence](docs/reader/evidence/f-active-content-2026-10-25.md) for exact local/hosted status. See the [native rendering evidence](docs/reader/evidence/f-rendering-2026-10-25.md) for exact checkpoints and image-capture limits. Function identifiers use English lowerCamelCase; readable descriptions belong in @Test display names.

Every app, test and ReaderKit target enables Approachable Concurrency and compiler warnings as errors in Debug and Release. The shared scheme uses Apple's automatic test plan. CI first executes the Swift Testing runner contracts directly, then runs the native Reader plan and the process-recovery probe. Automatic coverage focuses on Mac; manual coverage: all retains Mac/iPhone/iPad validation for final acceptance.

Full product acceptance remains open. Real network-off/restart, final devices/iPad windows, accessibility, representative model/feed quality, PCC entitlement and distribution retain their explicit requirements. PCC is disabled in the normal build. See [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45) and [cleanup evidence](docs/reader/evidence/k-reader-only-2026-10-25.md).

## Model verification

Foundation Models uses structured sessions with source references tied to stored article identities. Validation rejects generated links, unsupported numeric claims and blank content. Literal duplicate sentences/sections are removed without merging distinct source identities. New results, existing cache reuse and startup publication share content/source rules: invalid cards cannot hide originals, and originals-only cards require an explicit warning. Model and presentation-state contracts use Swift Testing; actual UI interactions remain separate.

[I evidence](docs/reader/evidence/i-generator-2026-10-25.md) retains reproduced failures and real local observations. German offer generation and semantic long-text quality remain unresolved; the multi-stage pipeline decision is pending. PCC requires approved Apple entitlement/provisioning and is disabled in this build. Full product acceptance remains open.

## OPML acceptance

OPML verification includes actual FreshRSS imports, repeated imports, confirmed folder renames, visible rejection and restoration of the isolated test account. Export follows current category membership while retaining matching imported hierarchy. A folderless repeat preserves an existing assignment. New subscriptions appear only after their complete initial refresh succeeds; confirmed existing feeds can merge import metadata without HTTP. H is accepted for this exercised Mac/server contract: Reader CI 40227398927 passes all 333 executions, including three forced initial-refresh failures. See [H evidence](docs/reader/evidence/h-opml-2026-10-25.md) for the exact scope, owner decisions, original audit distinction and raw evidence. Full product acceptance remains open.

## Attribution

This fork retains NetNewsWire's [MIT license and copyright notice](LICENSE). Local extraction uses pinned Mozilla Readability with its Apache-2.0 notice in ReaderKit/Sources/ReaderContent/Resources. English is the source language; German belongs in localization resources and explicit translation fixtures.
