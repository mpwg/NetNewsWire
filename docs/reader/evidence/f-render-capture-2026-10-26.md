# F: actual hosted article pixels — 2026-10-26

Status: **open**. This candidate narrows the existing hosted capture uncertainty without accepting it. In Reader CI 40278721330 at 846b16357, the actual Starred route, original selection and AX heading queries pass, but the inspected window screenshot leaves the WebKit body white. [Original capture and scope](b-star-retention-2026-10-26.md). A DOM string, accessible heading or hittable element is not painted-text proof.

## Candidate and criterion

The existing macOS Swift Testing hosted-article function already exercises the actual ArticleDetailView, its ReaderArticleState/WebPage, a real NSHostingView/NSWindow, successful/failed/empty/cancelled extraction, removal and weak graph release. The four existing parameter cases now export the current page as an image after pending screen updates, before removal. Apple Vision must recognize the expected saved heading for failure/empty/cancelled, or the extracted heading after success. The original image and recognized text are attached to each case. No expected text is read from DOM/AX for this pixel assertion; no retry or image replacement is added. Existing lifetime, cancellation, request, state and outbox assertions remain.

This uses Apple's [WebPage.exported(as:)](https://developer.apple.com/documentation/webkit/webpage/exported(as:)) with its [image configuration](https://developer.apple.com/documentation/webkit/webpage/exportedcontentconfiguration/image(region:allowtransparentbackground:snapshotwidth:afterscreenupdates:)), and native Vision RecognizeTextRequest. The image covers the top 800 × 300 points at width 800, afterScreenUpdates=true. A blank export or missing expected heading fails the case; a thrown export/recognition error propagates. The existing one-minute limit applies. The test is macOS-only, matching the already hosted component suite. Production rendering, parser isolation, foreign-resource blocks and the ten native UI methods are unchanged.

| Criterion | Status | Evidence |
|---|---|---|
| Candidate compiles with compiler safeguards | Fulfilled | Xcode MCP build-for-testing at 07:37:37 local time succeeds; no errors/warnings. The subsequent edit changes only the @Test display description. |
| Strict lint and whitespace | Fulfilled | Strict SwiftLint and git diff --check pass after the pixel-test addition. |
| Expected text appears in native WebKit image for all four outcomes | Open | New assertions have not executed yet. Preserve original image/OCR attachments and exact case results from fresh CI. |
| Actual app-window body pixels | Open | A WebPage image export is a separate capture path. Even if it passes, it does not replace the still-white native app-window screenshot or prove its cause. |
| Lifetime and cancellation under added capture work | Open | Existing four cases must pass again on this changed source; earlier passes do not prove the added work. |
| Held normal Reader is preserved | Fulfilled | No local test/relaunch is performed; PID 24529 remains present after the Xcode build. |

Current source-equivalent CI 40280649483 at 14d85474e predates these new assertions and cannot prove them. Inspect that running handle to completion before pushing this separate candidate; do not restart it solely because observation expires. Complete local app restart, actual offline, final iPhone/iPad, accessibility and distribution remain independently open.
