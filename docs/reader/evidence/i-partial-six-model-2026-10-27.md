# Six-source guarded local-model observation — 2026-10-27

One new text-only diagnostic used the existing fixed six-article public RSS projection, synthetic identities and timestamp, `de_AT` generation locale, an in-memory store and the actual on-device model on macOS 27.2 / 26B123. Runtime source was `dbd123b62` (the partial guarded-section correction). No FreshRSS server, linked page, UI, PCC or other network operation was used. Full publisher text, prompts and model responses remain in the owner-only 0700 directory / 0600 report outside Git. [Aggregate and exact input/report hashes](i-partial-six-model-2026-10-27.json).

In 26.430 seconds the coordinator returned one warned originals-only section covering all six original identities; article snapshots were unchanged and the outbox was empty. The trace contains five fact responses and no consolidation response. A separate temporary Swift Testing replay decoded the actual recorded prompts/responses and invoked the shipping `SourceFactValidation.excerpts`: the first four responses passed; the fifth, for packet 4, failed. Six of that response's seven excerpts have exact-byte matches in their own packet. The failed response is not repaired, and no inference is made about the unrequested sixth fact response or the model's semantic correctness. Xcode MCP model run `Test-Reader-2026.10.27_12-12-49-+0100.xcresult`; recorded-response replay `Test-Reader-2026.10.27_12-13-37-+0100.xcresult`. Both temporary tests were removed and the unchanged app/test target rebuilt through Xcode MCP at 12:14:20.

| Criterion | Status | Evidence / limitation |
|---|---|---|
| Preserve all originals and read/outbox state for this invocation | Fulfilled for this in-memory run | The native test asserted six original identities, unchanged store snapshots and no pending changes. |
| Preserve useful free sections in this six-source output | Not fulfilled | One invalid source-fact response stopped generation before consolidation. No mixed or free section was produced. |
| Attribute this failure to a specific validation boundary | Fulfilled for the recorded response | Shipping source-fact validation rejects packet 4; no claim is made that exactly one excerpt violates every boundary. |
| Real FreshRSS UI, representative model quality and complete platform acceptance | Open | This public-text projection and one local model call do not establish those operating modes or general quality. |

The next implementation may isolate an invalid original rather than accepting or silently repairing any of its unowned excerpts; it must discard that original's entire partial fact set, preserve other originals, and visibly warn. This observation alone does not implement or accept that behavior. No package closes.
