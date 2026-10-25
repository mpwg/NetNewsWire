# I: native model session contracts — 2026-10-25

This continues I/#54 after accepted B persistence and the exercised F Mac content-isolation core. The owner prioritizes macOS; final shared-platform and actual network-off acceptance remain separate. PCC is not configured or authorized in the shipping app and is not enabled by this work.

## Reproduced and repaired output boundary

The production AppleSummaryGenerator previously checked only lowercase HTTP(S) strings in group summaries. A URL in a group title or an uppercase HTTPS URL in a summary escaped rejection. Both failures are reproduced through an actual Foundation Models LanguageModelSession, its generated schema and a controlled LanguageModel executor: [original red result](i-output-red-2026-10-25.json), six passes and two failures. Validation now examines both title and summary case-insensitively. No model tools, foreign inference service, new public initializer or UI automation is introduced.

The existing private generation/session and cloud prerequisite helpers are now internal so native Swift Testing can call the same production paths with Apple's LanguageModel protocol. The lightweight fixture model/executor is test-only; its actor owns request observations with no shared global state. It emits JSON through Apple's native generation channel; the framework performs structured decoding before Reader validates the response. This is not a substitute implementation of Reader's parser or a production model backend.

## Controlled native contracts

Nine added Swift Testing functions cover 19 executions:

- Native guided generation, response limit, no enabled tools, deduplicated source numbers mapped to the exact stored article identity.
- Empty, negative and out-of-range references, unsupported numeric claims, summary/title HTTP(S) links and case variation.
- Real SDK guardrail, context-size, quota and missing-assets error values thrown by the controlled executor propagate with their exact native type and localized description.
- Insufficient runtime budget fails before any inference request. Two runtime capacities split a long Unicode source into multiple native sessions, preserve content and respect each prompt budget.
- Live cloud permission is checked before each chunk and blocks later requests after revocation. Unconfigured PCC is rejected before permission evaluation; revoked permission is rejected before PCC model instantiation. Neither case makes a cloud request or claims entitlement authorization.
- Native model cancellation remains CancellationError.

Together with the nine existing digest contracts, all **28 executions / 18 distinct tests** pass without failures/skips/runtime warnings through Xcode MCP on My Mac. [Raw focused summary](i-generator-focused-2026-10-25.json). Strict SwiftLint and git diff --check pass. The changed production logic is the URL validation; the two helper visibility changes add internal test access only.

An initial native inspection observes SystemLanguageModel.default.isAvailable=true and contextSize=8192 on this Mac. Constructed SDK errors already provide readable native messages, so no duplicate app-specific error translation layer is added. This inspection is not a generation-quality or unavailable-device result.

## Criteria

| Criterion | Status | Evidence or remaining work |
|---|---|---|
| Model/guardrail/context/quota errors surface | Fulfilled for controlled native session propagation | Actual SDK error values and exact native descriptions; insufficient-budget/no-request case. Actual device/model/PCC operational variants remain separate. |
| Sources use stored articles; reject model-written links | Fulfilled in controlled native contracts | Native structured session maps exact article identities, rejects invalid references/numbers and both reproduced URL cases. Full product quality remains open. |
| Runtime chunking and consent | Fulfilled for controlled native contracts | Unicode conservation at two capacities, prompt budget checks, live per-chunk revocation and pre-instantiation PCC gates. |
| Current full Mac plan / hosted CI | Open | Focused contracts pass; full current regression confirmation still required. |
| Actual on-device inference | Open | Current model availability observed; a current generation journal is still required. |
| Actual PCC | Not verifiable | Approved entitlement/provisioning unavailable; no PCC request is made. Availability alone does not authorize one. |
| Multilingual, representative and long-content editorial quality | Open | Controlled output proves contracts, not semantic accuracy or broad inference quality. |
| README and status documents | Updated | Root/package guides and current acceptance/handoff checkpoint. |

I/#54 remains open. Actual network-off/restart remains owner-deferred. Final iPhone/iPad/signing/accessibility, PCC, representative quality and broader memory/energy are not accepted by these code tests.
