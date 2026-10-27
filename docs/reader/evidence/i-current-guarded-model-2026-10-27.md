# Current guarded local-model coordinator observation — 2026-10-27

One new invocation on runtime source `06cc4ebef` used the same frozen two-text FreshRSS sample, synthetic identities and timestamp, `en_AT` generation locale, an in-memory store, the on-device model on macOS 27.2 / 26B123, and no cloud. The source snapshots were previously captured from a real temporary subscription; this invocation did not contact FreshRSS, fetch links or render the app. It is a single diagnostic observation, not representative quality acceptance. [Aggregate and protected-input/report hashes](i-current-guarded-model-2026-10-27.json). Full publisher text, prompts and output remain in the owner-only 0700 directory / 0600 report, outside Git.

After 17.546 seconds, the coordinator returned one warned originals-only section with both original identities. Stored article snapshots were unchanged and the outbox was empty. The opt-in trace records two successful fact responses and a consolidation response. That consolidation again claimed an explicitly near-new item was new. A separate temporary Swift Testing replay used the recorded packet-to-article references and actual consolidation text to confirm that the known-condition-upgrade rule matches this generated section and that the weekday rule does not. Xcode MCP `Test-Reader-2026.10.27_12-06-45-+0100.xcresult`. The original diagnostic and state assertions passed in `Test-Reader-2026.10.27_12-05-57-+0100.xcresult`.

The generated text was not published as a free summary. This is a successful negative safety/fallback observation for this one output, but a failure to produce a useful free digest for this pair. Both earlier model outcomes and the rejected prompt experiment remain recorded; no retry is selected as acceptance. The diagnostic tests were removed and the unmodified app/test target rebuilt successfully through Xcode MCP at 12:07:03. No UI test, OCR, device-network change, server mutation or PCC request occurred.

| Criterion | Status | Evidence / remaining work |
|---|---|---|
| Preserve both originals and read/outbox state for this actual local-model output | Fulfilled for this in-memory invocation | Original state, source sets and zero pending changes are asserted in the native code test. |
| Prevent this observed item-condition upgrade | Fulfilled for this output | Actual response and referenced source match the independent guard; the coordinator publishes originals with a warning. |
| Useful free summaries and source-bound compact fields | Open | The observed output produces no free digest. One supported fallback does not repair model semantics or field attribution. |
| Real-feed app/UI, actual offline restart, PCC and final devices | Open | Frozen text and an in-memory coordinator are not those operating modes. |

This observation does not change or close #54. The current source CI remains separate.
