# Reader

Reader is a standalone FreshRSS client for macOS, iOS and iPadOS **27 or later**, with a shared SwiftUI application and SwiftData store. Open **`Reader/Reader.xcodeproj`** in Xcode 27 and select the **Reader** scheme. The native project was created with Apple's multiplatform app template through Xcode MCP; it reuses the existing ReaderKit implementation.

The owner authorized Reader-only source retirement on 2026-10-25. The original NetNewsWire application and the superseded root Reader project/app/test copies are removed; Git history preserves them. `Reader/Reader.xcodeproj` is the only active app project. This source cleanup does not imply full product/platform acceptance.

## Accounts and storage

Enable API access in FreshRSS and set an **API password**. Enter the HTTPS installation URL or complete `…/api/greader.php` URL, username and API password. Reader uses the Google Reader compatible API, rather than an interactive browser/OIDC login. No private NetNewsWire API keys are required.

Debug uses `eu.mpwg.reader.debug`; Release uses `eu.mpwg.reader`. The store location and Keychain service derive from the bundle ID. Reader does not migrate existing NetNewsWire databases. A development team and appropriate provisioning are required for physical devices.

Downloaded articles remain available offline. Read/star changes and their versioned pending operations commit locally together and are sent during the next successful synchronization. A refresh succeeds only after all pages have been fetched and saved. Window activation uses a shared refresh coordinator; manual refresh remains available.

## Daily digests

Each feed can use ordinary articles or daily digests. Digests group articles by arrival day in a stored time zone and retain access to every original source. Search, stars and feed navigation expose individual articles; incomplete model coverage never hides unprocessed originals.

Opening content does not change read status. Marking a digest read affects exactly the sources of its displayed revision; later arrivals remain unread. Selection, search and sheets are independent in each window.

On-device Foundation Models inference is the default. Reader retrieves original pages when needed and extracts full text locally with Readability, without executing page scripts or using Feedbin's private extraction service. Website requests contact the corresponding website. Cancellation, source identity and content revision are checked before saving. Network errors, unavailable models and incomplete coverage remain visible.

**PCC is disabled in the normal build.** Apple's entitlement, signing and provisioning must be verified before enabling `AppleSummaryGenerator(privateCloudComputeEnabled: true)` and `ReaderServices(privateCloudComputeConfigured: true)`. Every cloud request also checks current per-feed consent. Revoking consent cannot undo an already transmitted request. No third-party AI provider is integrated.

Intelligence preferences and digests stay on the device. FreshRSS subscriptions and original article status synchronize across devices. Additional providers, direct RSS/Atom ingestion, widgets, extensions, AppleScript and theme import are outside this version.

## OPML

Import and export are available from Reader's menu. FreshRSS categories are flat: paths such as `A/News` and `B/News` become distinct categories, with hierarchy retained locally for nested OPML round trips. Server metadata takes precedence over local homepage fallbacks. Identical repeated imports are coalesced. Conflicting paths for the same feed are rejected before server writes.

## Architecture and testing

ReaderDomain provides Sendable snapshots and protocols. ReaderPersistence owns SwiftData and atomic write contracts. ReaderSync owns FreshRSS, Keychain, OPML import and bounded icon requests. ReaderContent handles HTML and OPML; ReaderIntelligence owns model and digest jobs. ReaderUI provides shared views and scene state.

**Approachable Concurrency and compiler warnings as errors are enabled for every Reader application/test target and all seven ReaderKit targets, in Debug and Release.** Swift 6 already enables three of Approachable Concurrency's five features; Package.swift explicitly enables `InferIsolatedConformances` and `NonisolatedNonsendingByDefault`, together with `.treatAllWarnings(as: .error)`. Library code retains its appropriate actor boundaries.

All code-testable app and runner behavior uses unhosted Swift Testing under `Reader/ReaderTests/`. Function identifiers use English `lowerCamelCase` without spaces; `@Test("Readable description")` supplies display names. Native XCTest/XCUIAutomation is limited to window/sheet lifecycle, real keyboard/menu/scroll interaction, rendering and view-task cancellation. Business validation, queries, counters, synchronization and ownership stay in code tests. Fixtures need no personal credentials or model requests.

Use Xcode MCP for interactive builds and tests. The shared Reader scheme includes both native test targets using Apple's automatic test plan. ReaderKit no longer declares separate SwiftPM test targets, so `swift test --package-path ReaderKit` is not the test entry point.

CI first runs ReaderRunnerTests directly through the native code-test target, independently of the aggregate shell runner. It then uses `scripts/test-reader.sh` for the full native plan, with no project generation or parallel Simulator clones. The runner collects every destination's outcome and fails if any fails; a failed build cannot test stale products. Its former Python unit suite is replaced by three Swift Testing functions / five cases using isolated fake executables. Run them from ReaderTests in Xcode MCP.

The SwiftData recovery probe separately exercises 10,000 synthetic articles across three real processes including SIGKILL. See [recovery evidence](../docs/reader/evidence/b-2026-10-24.md). This establishes core recovery, not complete app UI recovery or real FreshRSS behavior.

Current Mac evidence includes native/code/hosted query, menu, selection and counter contracts, controlled refresh ownership/cancellation and exact process recovery. Earlier runner initialization failures remain historical evidence. Native Release builds and separate Debug/Release stores are verified at their recorded checkpoints. English resources use explicit package bundles; German translations and plural forms have compiled-resource code tests. See the [test review](../docs/reader/test-review-2026-10-24.md) and [acceptance matrix](../docs/reader/acceptance.md) for current scope and limits.

## Attribution

Local extraction uses Mozilla Readability and JSDOMParser pinned to `ab4027a8b37669745016869a37a504727992b2ba`. Unmodified sources and Apache-2.0 license are under `Sources/ReaderContent/Resources/`. Foundation resolves URLs. NetNewsWire's MIT license and copyright notices remain.

Work plan: [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45), packages #46–#56.
