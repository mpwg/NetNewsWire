# Digest original navigation candidate — 2026-10-27

The real-FreshRSS local-model diagnostic produced one summarized source and one originals-only fallback; its coordinator references both, but it did not render or navigate an app UI. Candidate `codex/reader-original-navigation` / `8b8035ef2` changes the existing isolated Mac UI fixture to that two-section shape and extends its existing bilingual fallback test to open each original and check that opening it does not create a pending read change. The fixture uses synthetic articles and an in-memory store; it is not an end-to-end real FreshRSS or actual-model test. No OCR or image analysis is used.

The first local Xcode MCP UI attempt failed before reaching the added navigation assertions: XCTest launched the app but observed no first window within ten seconds (`ReaderUITests.swift:630`; `Test-Reader-2026.10.27_10-42-42-+0100.xcresult`). No Command-N or other window creation was injected. A separate ordinary Debug launch via Xcode MCP then exposed one initial Reader window in the macOS accessibility hierarchy without a keyboard command; it was stopped through Xcode MCP. This single ordinary launch does not explain the test-runner discrepancy, prove fixture startup, accept accessibility or establish a repair. The earlier hosted UI results remain separate.

The failed XCTest accessibility hierarchy contains the Reader menu bar but no window. AppKit logged that no windows were open during that launch. An App Intents service connection error also appeared during the successful ordinary launch, so it does not establish the cause of the test failure. The cause remains undetermined; the exported hierarchy contains local system information and is not included in the repository.

## Terminal hosted result

[Reader CI 40483008168](https://github.com/mpwg/NetNewsWire/actions/runs/40483008168) on exact candidate `8b8035ef26d2b947e86f4ad0c7cb382ba7dbf07e` is **failed**: 574 passed executions and one failure, zero skips; 265 passed distinct tests and one failed. All 564 code executions and ten of eleven native UI methods pass. SwiftLint, runner failure propagation and process recovery pass. The hosted Mac uses macOS 27.0.1 / 26A434 on arm64 Virtual Machine. [Original summary](i-original-navigation-ci-summary-2026-10-27.json), [selected case nodes](i-original-navigation-ci-cases-2026-10-27.json), [recovery](i-original-navigation-recovery-2026-10-27.json).

`testOfferFallbackAppearsInActualDigest` passes in 77.566 seconds. Its English and German launches each open their first window without Command-N, show both localized fallback notices, open summarized source `Timeline article 0` and originals-only source `Timeline article 1`, observe each actual detail title, and observe zero pending read changes after each opening. These synthetic native assertions are now proved on the hosted candidate. They neither repair the local launch discrepancy nor establish real-feed/model app integration.

The sole failed method is `testVoiceOverAnnouncesReaderAndMovesFocus`, at line 95 while requesting the final window screenshot. Its actual speech reaches both required adjacent titles, but the test loses its helper connection and does not produce a restoration attachment. Three archived `testmanagerd` reports capture `EXC_BAD_ACCESS` / `SIGSEGV` at 09:56:17.8850, 09:56:29.0674 and 09:56:31.4171 UTC. All faulting stacks begin `objc_release`, autorelease-pool cleanup and XPC message handling. These captures precede the line-95 error at 09:56:33.7729 UTC; the final screenshot is not established as the initiating cause. Removing it would not establish service reliability or restoration. [Original activities](i-original-navigation-voiceover-activities-2026-10-27.json), [exported speech/state text](i-original-navigation-speech-2026-10-27.json), [selected original crash fields](i-original-navigation-crash-receipt-2026-10-27.json). No OCR or pixel analysis was performed.

GitHub artifact `12725215159` (`reader-macos-results`, 132,537,409 bytes) reports digest `sha256:1c1a30dd36db3d9833d29b3c8ff4553dc7e58b879d4a279e5c779d5145b39683`; the artifact was downloaded and inspected. This records GitHub's archive metadata, not an independently checked ZIP checksum. Full original results remain in that artifact.

| Criterion | Status | Evidence / next action |
|---|---|---|
| Navigate summarized and originals-only synthetic sources in English/German | Fulfilled on candidate | Actual detail titles and zero pending reads in the passing native method. |
| Complete hosted Reader plan | Open | VoiceOver helper loss; retain failure and diagnose service/restoration before integration. |
| Local XCTest first window | Open | Local runner still observed no window; ordinary launch and hosted success have separate scope. |
| Real-feed/model app links, complete VoiceOver, final platforms | Open | Synthetic navigation does not establish these criteria. |

The candidate remains outside main because the complete plan failed. No unchanged retry, skipped test, timeout extension, package closure or product acceptance follows.
