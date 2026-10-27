# Opt-in model failure diagnostics — 2026-10-27

The earlier item-condition candidate fell back to originals without identifying which model request failed. The isolated evaluation trace now records `facts-error` or `consolidation-error`, the original request/instructions and the reflected error when a native request throws before producing a response. Completed responses retain the existing trace and independent validation. These records are diagnostic data, not repaired model output or a semantic acceptance gate.

The shipping app installs no trace sink. Opt-in evaluation reports can contain source text and error details and must stay outside the repository when using publisher/account data. No new logger, transport, model, cloud request, prompt change, retry or output repair is introduced. The original error is rethrown; cancellation is not classified as inference failure.

| Criterion | Status | Evidence |
|---|---|---|
| Identify fact/consolidation request failure and retain original error | Fulfilled for controlled cases | Two parameterized Swift Testing executions assert the stage, original request/instructions, empty response and exact `ReaderError.invalidResponse`. |
| Preserve cancellation | Fulfilled for controlled case | Injected cancellation remains `CancellationError`, emits no failure trace and starts no later request. Existing sink-cancellation tests also pass. |
| Current Mac code regression suite and lint | Fulfilled | Xcode MCP: 567 executions, zero failures/skips, `Test-Reader-2026.10.27_11-26-21-+0100.xcresult`; strict SwiftLint 0.65.1 passes. Build-for-testing also passes. |
| Explain the earlier real-model failure / improve semantic quality | Open | A controlled error is not a diagnosis of a historical native call or proof of summary quality. A separately recorded native diagnostic is needed. |
| Complete hosted/native/platform acceptance | Open | Previous VoiceOver/helper failure remains; local window comparison is owner-deferred. PCC and final devices remain separate. |

README and the main acceptance matrix link this bounded diagnostic. It does not close #54 or another package.
