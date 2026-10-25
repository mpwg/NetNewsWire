# F / #51: bounded article downloads — 2026-10-25

This continues the [native article checkpoint](f-rendering-2026-10-25.md). ArticleContentService previously checked the 4,000,000-byte limit only after URLSession.data had buffered the complete response. An error status also waited for the response body. The existing oversized-response test proved parser rejection, not early transport cancellation or bounded retained payload.

## Reproduction and implementation

The new Swift Testing fixture sends real URLProtocol header/chunk callbacks into the shipping service and holds completion behind a cancellation-aware gate. Four initial executions fail: HTTP 403 headers, an oversized declared length, excess bytes without Content-Length, and excess bytes beyond an underreported length. The original service cannot return while completion remains held. One exactly-at-limit success already passes. [Initial raw failure](f-stream-red-2026-10-25.json), original 17-55-36.

The service now owns one native URLSessionDataTask with a task-specific delegate, following the pattern already exercised by the icon service. It validates response status and declared size before accepting body data. Each received chunk must fit in the remaining payload budget before it is appended; overflow cancels that request. Cancellation before start, during headers or during body delivery settles through the native completion callback. Completion clears task, continuation and payload references. The injected URLSession remains caller-owned; the service never invalidates it. No new module or package dependency is introduced.

HTTP errors retain their typed ReaderError.server status. Size rejection retains ReaderError.invalidResponse. The exact 4,000,000-byte success remains accepted. The original direct parser input-size check remains as a separate boundary. This bounds Reader's accumulated response payload, not total process RSS, Foundation/network buffering, parser allocations or energy.

## Swift Testing coverage

ContentStreamingTests adds three functions / seven executions, with no new UI method:

- Four header/overflow outcomes require caller completion and transport cancellation while the server completion gate stays closed. No successful EOF is sent. All three weak references to service, transport and scripted plan subsequently disappear.
- Two explicit cancellation stages hold either headers or the exact-limit body before EOF. The request returns CancellationError without opening the corresponding gate; the transport stops and its weak graph releases.
- One streamed response at exactly 4,000,000 bytes completes and produces the expected article text.

The shipping extraction/session/store and existing timeout/relative-link/error/lifetime contracts remain in the focused run. The final focused run at 17-58-25 passes **51 executions**. [Raw result](f-stream-focused-native-2026-10-25.json). Native build-for-testing through Xcode MCP, strict SwiftLint and diff checks pass.

The complete native My Mac plan at 17-58-31 passes **154 Swift Testing functions / 269 executions plus seven unchanged UI methods / 276 total executions**, 161 distinct tests and 45 parameterized functions / 160 cases, no failures/skips/runtime warnings. [Raw full-plan result](f-stream-full-native-2026-10-25.json). Hosted confirmation of this source checkpoint remains pending. No additional UI scenario is added for the download rules.

## Native component harness observation

The first expanded run passes all new stream cases but times out once waiting for the hosted article's updated WebPage DOM. [Preserved failure](f-stream-first-native-view-failure-2026-10-25.json), original 17-56-25. A repeat of the view/stream suites passes all nine executions before harness changes; this does not establish a shipping rendering defect or a cause for the timeout.

The component harness now observes ReaderSession.selectedArticle in a stable SwiftUI parent, matching production input updates and article identity. It no longer replaces NSHostingView.rootView just to publish extracted content. Root replacement remains only for the actual removal criterion. Shipping rendering code and the five-second wait are unchanged. All four component outcomes pass in the final focused run. Broader native/capture reliability is not silently accepted from a retry.

## Criteria

| Criterion | Status | Evidence or remaining work |
|---|---|---|
| Reject error/oversized headers before consuming their body | Fulfilled on exercised Mac code | Two controlled cases settle while the first body gate remains held. |
| Reject actual byte overflow with missing or inaccurate length | Fulfilled on exercised Mac code | Both cases cross the actual limit, cancel and return before server completion. Source appends only chunks fitting the remaining budget. |
| Exact-limit and existing extraction semantics | Fulfilled in focused run | Exact streamed limit, current/stale result/error, HTTP 403, timeout, parser/link and store/lifetime contracts pass. |
| Cancellation and release | Fulfilled in focused run | Held headers/body cancel, no EOF is sent, and service/transport/plan weak references disappear; existing extraction graphs remain passing. |
| Full current native Mac confirmation | Fulfilled | All 276 executions pass after the final code/harness changes; native build and strict lint pass. |
| Exact-source hosted Mac confirmation | Open | Pending for the streaming follow-up; the preceding 7e9ee89c2 checkpoint remains green in Reader CI 40212463634. |
| Whole-process resource and final product acceptance | Open | Parser/process memory and energy, representative sites/media, owner-deferred actual network-off/restart, final iPhone/iPad, accessibility, PCC and separate-device FreshRSS remain independent. |

F and mapped #33/#34 remain open. Earlier evidence accurately describes the former buffered implementation; this checkpoint supersedes that particular implementation limit only after its final checks. Keep the separate Swift CodeQL tracer failure visible under K.
