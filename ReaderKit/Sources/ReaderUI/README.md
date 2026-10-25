# ReaderUI

Normal feed rows load thumbnails through the shared FeedImageService actor. Each icon reads its nearest display scale and a Dynamic Type scaled size, cancels its view task when its request changes, and checks cancellation before replacing the displayed image. ImageIO decoding stays outside MainActor. Missing or invalid images use a system-symbol fallback; digest feeds keep their Sparkles mode symbol. This wiring does not by itself establish native responsiveness or energy acceptance under image load.

The native Mac image-load scenario now verifies scrolling and account-form interaction while the shipping pipeline handles large synthetic homepages, HTTP 503 fallbacks and 4096-pixel images. Removing all fixture feeds makes their actual view tasks disappear; additional transport cancellations and zero active requests are required, with a maximum of three simultaneous requests. [Window screenshot and exact scoped results](../../../docs/reader/evidence/g-2026-10-25.md) record this Mac observation. The fixture is Debug/Mac-only, isolated in memory and uses no real credentials. Final platform and broad energy acceptance remain separate.

Shared SwiftUI views for macOS, iOS and iPadOS 27 and later. Every ReaderWindow owns a ReaderSession with its own selection, search, presentations and query generation. ReaderServices shares only persistence, FreshRSS and content/intelligence services.

Articles and daily digests remain accessible together. Search, stars and feed navigation expose originals; incomplete or failed summaries never hide unprocessed articles. Opening content changes no read status. Marking a digest read uses exactly the sources of its displayed revision.

The list queries pages of up to 200 articles. Covered originals are filtered while gathering rows; further raw pages load until enough visible articles are available or the store is exhausted. A large deal feed therefore cannot displace ordinary feeds from the first visible page. Selected articles and sources load by account-scoped identity. The footer distinguishes visible entries from loaded originals. Store revision streams invalidate other windows. UI state belongs to MainActor; services own I/O.

Scene activation refreshes FreshRSS. Simultaneous windows share the same owned job; automatic refresh does not repeat within 60 seconds of success. Manual refresh forces synchronization. Cancelling one window's task does not cancel shared account work. iPhone navigation initially shows the sidebar, making account setup directly accessible.

The app uses the native Apple-template project at `Reader/Reader.xcodeproj`; do not run the superseded generator. ReaderSessionTests and other state contracts use Swift Testing with isolated stores. ReaderSmokeTests remains native XCTest/XCUIAutomation. The first Mac window must open automatically without Command-N. The second-window test keeps both sheets open and checks independent drafts/cancellation. Window cycling uses the native keyboard command so overlapping windows on small displays do not turn clicks into interactions with the wrong window.

English is the source language. Text and control resources explicitly use this module's bundle; German translations and plural forms live in its String Catalog. Domain/formatting checks primarily run as code tests, including compiled English/German resources.

No legacy UIKit controllers, global scene lookup or device-wide geometry assumptions are used. Physical devices, VoiceOver, keyboard coverage, RTL, Dynamic Type and multiple iPad windows still require separate practical acceptance. The earlier direct-AX diagnostic inside a sandboxed runner was not evidence that XCTest lacked permission; see the corrected [test review](../../../docs/reader/test-review-2026-10-24.md).
