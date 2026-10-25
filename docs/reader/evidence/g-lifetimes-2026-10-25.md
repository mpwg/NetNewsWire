# G / #16 / #30: service lifetimes and credential failures — 2026-10-25

This step continues the accepted native Reader implementation on macOS. G remains open for its complete acceptance scope and deferred platform checks. No legacy targets or foreign changes are removed.

| Contract | Current result | Evidence |
|---|---|---|
| Credentials fail without blocking retries | Fulfilled in controlled native code paths | Nine operation/status combinations inject errSecNotAvailable, errSecInteractionNotAllowed and errSecAuthFailed. Each produces the unavailable error with the same numeric status and exactly one OS call. |
| Cancellation prevents later recovery writes | Fulfilled | Two controlled gates cancel after the initial update or duplicate-item add. No subsequent add/update starts. Removing the two new guards causes both cases to fail, with the unwanted complete update/add/update sequence. |
| OS work leaves MainActor free | Fulfilled in the controlled scenario | A bounded synchronous adapter blocks a read. The MainActor test releases it while it is still waiting; the operation returns successfully without timing out. It models the OS-call boundary and makes no real credential read. |
| Device-local protection survives creation races | Fulfilled | Update-not-found/add-duplicate/update-success preserves service/account identity, synchronizable=false and AfterFirstUnlockThisDeviceOnly protection. |
| Complete service graph releases | Fulfilled on exercised Mac paths | Weak references to store, credentials, FreshRSS client, icon/image/content services, generator/coordinator, presentation services/session, fixture transport and server all become nil after necessary work. Success, HTTP 503 and a cancelled window waiting on shared work are separate parameter cases. |
| Image-job ownership releases | Fulfilled | Real-PNG completion and cancellation before homepage response require icon/image actors and the invalidated fixture session to become nil. |
| Chunked bounds remain enforced | Fulfilled | Missing Content-Length with 64-byte chunks accepts exactly 128 bytes and rejects 129 for a 128-byte limit. Existing MIME, declared-length, fallback, cache and cancellation contracts also pass. |
| Real credential revalidation | Passed after owner permission | The first native probe timed out inside SecItemCopyMatching → SecurityServer::ClientSession::decrypt. After the owner confirmed allowing access, the fresh Xcode MCP native diagnostic reads the stored API credential, finds the one isolated feed and decodes its real 32×32 thumbnail. No password or token is printed. [Exact safe output](g-live-lifetimes-2026-10-25.txt). |
| README | Updated | ReaderSync documents the adapter, fail-fast semantics, follow-up cancellation checks, native data-task ownership and explicit limits. |

## Changes and rationale

KeychainCredentialStore keeps its public system-backed initializer. An internal synchronous KeychainAccess adapter permits deterministic OS-error injection. The actor keeps the blocking Security calls outside MainActor. It now rechecks cancellation before starting each add/update recovery operation. An OS call already in progress is allowed to complete; cancellation does not roll back a completed OS operation.

The initial full-graph test released every Reader-owned object but retained the injected URLSession. Independent Xcode MCP native diagnostics reported an unused ephemeral session released, a completed data(from:) session released and an early-cancelled bytes(from:) session still retained after three seconds. This is an observed runtime result, not a claim of a permanent or universal Foundation defect.

Icon downloads now use a native data task and task-specific URLSessionDataDelegate. They validate status/MIME/declared size before accepting the body, reject oversized chunks before accumulation exceeds the bound, propagate cancellation, and finish from didCompleteWithError. Completion clears the owned task and continuation. The supplied URLSession is preserved for its caller. The full graph and image-job tests now also require transport release; the failing assertion was not removed.

The service graph includes the real ReaderStore, KeychainCredentialStore, FreshRSSClient, IconService, FeedImageService, ArticleContentService, DigestCoordinator, ReaderServices and ReaderSession. Its summary adapter and network/OS responses are isolated fixtures. It runs a sourced digest job, a gated refresh, an image failure and a store observer, then finishes/cancels necessary work and drops all strong fixture references. ReaderAccount is a value; legacy Local/CloudKit account/delegate objects are not instantiated or claimed as tested.

## Current native verification

The full plan passes **101 code functions plus the unchanged three UI tests / 143 executions**, zero failures/skips/expected failures. Original authoritative bundle:

`/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.25_11-34-56-+0100.xcresult`

Raw xcresult summary confirms 104 distinct tests, 14 parameterized functions / 53 cases and no runtime warnings. The MCP-exported copy lacks Info.plist; it is not the count source. Xcode MCP built/ran the Mac plan with the existing concurrency/warning policy; whole-repository SwiftLint strict passes. Hosted revalidation is pending.

## Retained failures and diagnostics

All local result suffixes below belong to ActionArtifacts/default/RunSomeTests; original DerivedData copies remain the fallback when an export is incomplete.

- `Test-Reader-2026.10.25_11-09-38-+0100.xcresult`: nine new error cases initially assumed ungrouped diagnostic numbers. The test now compares the numeric code independently of supported localized grouping.
- `Test-Reader-2026.10.25_11-12-08-+0100.xcresult`: controlled removal of both recovery cancellation guards makes exactly the two new cancellation cases fail; fourteen other cases pass.
- `Test-Reader-2026.10.25_11-17-55-+0100.xcresult`: all three graph outcomes retain only transport after the previous byte-stream path; twenty-three other selected cases pass.
- `Test-Reader-2026.10.25_11-29-55-+0100.xcresult`: an intermediate cleanup illegally reset the task delegate after resumption. Foundation raised Cannot set task delegate after resumption and aborted xctest. That reassignment was removed; the delegate is now assigned only before resume.
- `Test-Reader-2026.10.25_11-31-34-+0100.xcresult`: all 41 focused credential, graph, image and icon cases pass after repair. The final full plan additionally includes the new two chunk-boundary cases.

No new UI test, device run or real credential mutation was introduced for these contracts. Final iPhone/iPad, full persistent-app restart, multi-device/offline synchronization and broad accessibility/energy/distribution/PCC acceptance retain their open scope. The live diagnostic is a native integration observation, not an automated code-test execution.
