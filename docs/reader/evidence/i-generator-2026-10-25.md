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

Together with the nine existing digest contracts, all **28 executions / 18 distinct tests** pass without failures or skips; one native runtime warning records the injected guardrail case through Xcode MCP on My Mac. [Raw focused summary](i-generator-focused-2026-10-25.json). Strict SwiftLint and git diff --check pass. The changed production logic is the URL validation; the two helper visibility changes add internal test access only.

An initial native inspection observes SystemLanguageModel.default.isAvailable=true and contextSize=8192 on this Mac. Constructed SDK errors already provide readable native messages, so no duplicate app-specific error translation layer is added. This inspection is not a generation-quality or unavailable-device result.

## First actual inference and prompt correction

The unchanged production checkpoint 9dd69dce8 was run natively through Xcode MCP with four synthetic inputs and cloudAllowed=false/privateCloudComputeEnabled=false. [Original captured output](i-local-before-prompt-2026-10-25.json) is retained unchanged, including its quality failures. The two offers preserve both merchants and exact EUR 29.99/EUR 49.00 prices. The news result unexpectedly uses Spanish and covers only one of two sources. A 12,006-token repeated source exceeds the observed 8,192-token context and successfully produces chunked output, but it takes about 58 seconds and repeats sentences extensively, with mixed Spanish/English output. The injected source instruction to invent a refund/link is ignored in this one observed case. These are narrow functional observations, not broad editorial acceptance or an immunity claim. The journal is explicitly captured model output, not canonical documentation prose.

The language instruction previously named only a locale tag. It now names the requested language in English, asks for consistent output language, at most two sentences per summary, no repeated claims, and coverage of every source using its actual facts. The locale remains the current locale; the internal session seam accepts an explicit locale for deterministic English/German contracts. Two failing prompt contracts are retained in [red result](i-prompt-red-2026-10-25.json). Both then pass with the full focused generator/digest set: **30 executions / 19 distinct tests**, zero failures/skips and one runtime warning for the injected guardrail case. [Current focused summary](i-prompt-focused-2026-10-25.json). The prompt assertions establish the request sent to the model; they do not prove that a real model will follow it. Current actual inference and regression revalidation remain required after this change.

## Real prompt follow-up and exact duplicate removal

[The next actual local run](i-local-after-prompt-2026-10-25.json) uses source fingerprint a6094be826b39743f22cd13303ecb53d9aaa2e27da75b8907a0dba410c18d01d. In this observation all output is English, matching the recorded requested language, and both news sources are covered. The 12,006-token input completes in about 18.5 seconds, but still returns two identical sections, each repeating the same sentence twice. Two controlled native cases reproduce that exact defect, including decimal EUR 29.99: [red result](i-repeat-red-2026-10-25.json).

The generator now uses Apple's NLTokenizer sentence boundaries and removes only exact duplicate sentences. Text without duplicates remains unchanged. It then removes exact duplicate DigestSection values while preserving order; the identity includes title, normalized text and the exact stored source-key array, so equal text from different stored sources remains separate. No semantic merging or invented replacement claims are performed. The two duplicate cases and a distinct-source preservation case pass. The final focused generator/digest set passes **33 executions / 21 distinct tests**, zero failures/skips and one runtime warning for the injected guardrail case, and strict lint. [Current raw summary](i-final-focused-2026-10-25.json). These tests establish literal duplicate handling, not general editorial accuracy.

## Final actual local observations and preserved error state

[Final public-generator journal](i-local-final-2026-10-25.json) · [exact native snippet](i-local-probe-2026-10-25.txt). Source fingerprint 0e90f56c9a8d76eeaec88db611cf730c90863a3f90252e9172907ea486ddf0db matches the owning generator. All four narrow local cases complete with cloudAllowed=false/privateCloudComputeEnabled=false. The two offers retain exact merchants/prices, both news sources are covered in English, the 12,006-token source runs through the 8,192-token model context in about 18.7 seconds, and the single injected instruction is ignored. Exact repeated sentences are removed, but the long output still contains two semantically overlapping sections with different wording. That remaining quality defect is not hidden or accepted.

[Explicit German journal](i-local-german-2026-10-25.json) · [exact snippet](i-german-probe-2026-10-25.txt). The same native production session with an explicit de_AT locale summarizes both news sources in German. The offer case is rejected by the existing numeric/link validator. Its discarded response was not captured, so the report does not establish its exact failure cause. A [separate fresh diagnostic request](i-german-raw-2026-10-25.json), using the same schema/instructions and source texts before Reader validation, converts EUR 29.99 into 29,99 EUR, translates the merchant name and omits the second offer. [Exact diagnostic snippet](i-german-raw-probe-2026-10-25.txt). This supports a localization/fact-fidelity concern; it is not the previously discarded response and is not claimed as one. Numeric validation has not been loosened to accept such output. Captured non-English model strings are explicitly translation/evaluation fixtures.

Four further native SDK-error scenarios at DigestCoordinator/ReaderStore prove that the exact localized warning remains visible, every original is retained with unchanged title/text and unread state, all source links remain available and the outbox stays empty. This is controlled error-state integration, not a real PCC outage/quota experiment. The complete focused set now passes **37 executions / 22 distinct tests**: thirteen added Swift Testing functions / 28 executions plus the nine original digest functions. [Current raw summary](i-complete-focused-2026-10-25.json). Strict lint passes; no UI method is added.

## Current acceptance matrix

The final full native My Mac plan at 21-04-56 passes **189 Swift Testing functions in 31 suites / 354 code executions plus seven unchanged UI methods / 361 total**, 196 distinct tests, 63 parameterized functions / 228 cases, zero failures/skips. [Raw full result](i-full-native-2026-10-25.json). It contains **one runtime warning from the deliberately injected native guardrail error**, also present in the focused summaries. Earlier text incorrectly said those focused runs had zero runtime warnings; that statement is corrected without editing any raw result. This runtime diagnostic is preserved; compiler warning promotion remains enabled and strict lint passes.

The normal Debug Reader is restored through Xcode MCP, PID 88938. Read-only inspection of that normal app's signature shows App Sandbox, user-selected read-only file access, Debug get-task-allow and network-client entitlements; the approved PCC entitlement is absent. No provisioning or cloud request is claimed. Reader CI 40229062088 is running on exact code/test checkpoint 3f09d9ac6; lint, direct runner failure propagation and process recovery have passed. Separate Swift CodeQL 40229062297/job 121276675260 again exits 139 in preload_tracer/autobuild before analysis, while the other three language jobs pass. The owner architecture question about multi-stage source-bound facts/consolidation versus separate warned chunks remains pending; dependent changes have not begun.

| Criterion | Status | Evidence or remaining work |
|---|---|---|
| Model/guardrail/context/quota errors surface | Fulfilled for controlled native session propagation | Actual SDK error values and exact native descriptions; insufficient-budget/no-request case. Actual device/model/PCC operational variants remain separate. |
| Sources use stored articles; reject model-written links | Fulfilled in controlled native contracts | Native structured session maps exact article identities, rejects invalid references/numbers and both reproduced URL cases. Full product quality remains open. |
| Runtime chunking and consent | Fulfilled for controlled native contracts | Unicode conservation at two capacities, prompt budget checks, live per-chunk revocation and pre-instantiation PCC gates. |
| Current full Mac plan | Fulfilled on My Mac | 361 executions pass, including all 354 code executions and seven UI methods. One deliberate guardrail runtime warning is preserved. |
| Exact-source hosted CI | Open | Reader CI 40229062088 on 3f09d9ac6 is running; lint, runner failure propagation and process recovery have passed. |
| Actual on-device inference | Fulfilled only for the named narrow native observations | Public default local generator runs four synthetic cases, including a 12,006-token input. Explicit German news runs; offers reject and semantic duplication remains. No broad quality acceptance is claimed. |
| Actual PCC | Not verifiable | Approved entitlement/provisioning unavailable; no PCC request is made. Availability alone does not authorize one. |
| Multilingual, representative and long-content editorial quality | Open | Retained wrong-language/coverage/repetition observations; German offer rejection and fresh diagnostic price/merchant changes; semantically overlapping long sections remain. Real representative inputs and broader editorial evaluation are still required. |
| README and status documents | Updated | Root/package guides and current acceptance/handoff checkpoint. |

I/#54 remains open. Actual network-off/restart remains owner-deferred. Final iPhone/iPad/signing/accessibility, PCC, representative quality and broader memory/energy are not accepted by these code tests.
