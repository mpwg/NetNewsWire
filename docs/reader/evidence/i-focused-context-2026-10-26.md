# I: selected assertions with complete supporting context — 2026-10-26

Status: **separate research candidate, not adopted**. Main remains the accepted v5 shipping implementation; #45/#54 remain open.

The preceding quoted-injection trace selects only sentence1 (the completed roof repair), yet its final summary includes the unrelated quoted price instruction. The context-preserving checkpoint had discarded the selection marker before drafting. The candidate now carries exact `selectedExcerpts` separately from complete original `text`, with Reader-assigned packet/article identities. The planner/drafter sees both. Context supports the conditions of selected claims; it is not an invitation to summarize every quotation. This remains model guidance, not a semantic guarantee or trusted reviewer.

Focused evidence is atomic during batching: selected excerpts and the complete bounded source fragment must fit their actual serialized JSON/instruction budget together, or generation fails explicitly. No silent context truncation or label remapping occurs. The initial source-fragment boundary and later hierarchical free-summary fidelity remain separate limits. Identical context merges only when selected excerpts also match; different selections keep independent identities. Default flags remain false, nil focus does not add a JSON key, and the shipping/default prompt is unchanged. No read/outbox/store/cache-policy changes or model tools are introduced.

## Current native code criteria

| Criterion | Status | Evidence |
|---|---|---|
| Selected claim and complete original context reach actual native requests | Fulfilled on current Mac candidate | Strengthened ordinary/isolated controlled-executor integration inspects both fields. |
| Equal context with equal/different selections retains exact source identities | Fulfilled on current Mac candidate | Four new native cases check merge/no-merge in ordinary and isolated paths. |
| Focus and context budget overflow fails before consolidation | Fulfilled on current Mac candidate | New actual-token-counter contract rejects the paired JSON after one selection request, without truncating context. |
| Existing references, numeric/content checks, budgets, cancellation, consent and store/coordinator contracts | Fulfilled for exercised Mac code boundary | All62 intelligence Swift Testing functions /145 executions pass via Xcode MCP, zero failures/skips. |
| Free app-language summary/long-text/representative offer quality | Open | Fixed changed-source model series pending; no previous model observation is relabelled. |
| PCC, final devices, accessibility, performance and deferred offline/app restart | Open | Existing missing authorization/prerequisites and owner deferrals remain unchanged. |

Xcode MCP app/test build16:11:43 and package probe build16:12:48 pass. Native run16:11:54 uses arm64 My Mac, macOS27.0.1(26A434); no normal Reader process was present and no UI test/app launch occurred. [Original summary](i-focused-code-summary-2026-10-26.json) and [all module case nodes](i-focused-code-cases-2026-10-26.json). Discovery has255 enabled distinct tests, zero disabled; this is not full-plan runtime evidence. Generator SHA-256 `2b3770c202e5bf695ffca95cddf5f02fccfb7aef79bc1a3fd72f6da70f02afc2`.

## Changed-source model observations and style correction

Functional commit0603f47082c4745e5e0db3053f2557c80758d2ba is probed once per fixed scenario with `--trace --isolate --sentences`. News preserves Thursday and both originals without duplicate sections. Conditions preserve Friday/Tuesday/resident restrictions in German. Offers retain both merchants, exact prices and all purchase restrictions. Quoted injection selects only completed roof repairs and no longer includes the irrelevant quotation. The long input reaches four bounded selections and drafting, then rejects the response: it formats source250000 as250.000 and adds inline citation digits `(0)` / `(0,1)`, which the strict unsupported-number check does not permit. No output is silently repaired or accepted. This five-case observation is not representative semantic acceptance or a prompt-injection guarantee. [Every complete synthetic report](i-focused-model-2026-10-26.json).

CI40347228928 is independently live on0603f4708. Its SwiftLint job121657296119 fails on exactly two `implicit_optional_initialization` errors at generator lines36/59. Native tests remain live; inspect the same handle before dispatching a changed-source follow-up. Removing the two redundant `= nil` initializers through Xcode MCP fixes the style without changing the fields' default nil behavior. SwiftLint0.65.1 (the exact CI version, installed only under /tmp) passes strict lint locally. Xcode MCP app/test build16:16:17 and the repeated62-function /145-execution native module run pass, zero failures/skips. Post-style generator SHA-256 `5d62cb825d25f125a26f60f545ba7286f0127e9ac1ee9d06ea5702efec48c367`.

The MCP-exported second result bundle lacks Info.plist; the authoritative original at `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.26_16-16-17-+0100.xcresult` is used for [the post-style summary](i-focused-style-code-summary-2026-10-26.json). Do not mistake an incomplete exported copy for a failed native run. Earlier back-to-back results also represent five previously targeted parameterized methods as single test-case nodes; do not extrapolate argument coverage from function counts. Their separate targeted16-case receipt and the current complete145-execution run provide their actual case evidence. No cause for that result representation is claimed.

No public source corpus is available for an exact-byte replay; no network, account credentials, PCC or OCR is involved in model evaluation. Do not retry unchanged failures for green or weaken provenance validation. Previous candidate CI40340848512 is successful on4bbf6f997 only; it cannot execute this change. Preserve the separate branch and restore main source/binaries before handoff.

## Shipping restoration

Research is committed/pushed at94e7315c3 only. Main v5 generator/probe SHA-256 values are restored exactly to `604700192553e84b886a3a8246f2eb5631f6481745cfee8c96c1d9b57f0e260e` / `8d0a2c1fcdcb5293fb619a6873eb5741e0c166321343d58a3464a803ac527632`. A temporary/reversed Package.swift newline refreshes Xcode's cached candidate-file graph; the manifest has no diff. Xcode MCP app/test build16:20:34 and package probe build16:20:47 pass; Reader/My Mac is restored. No candidate implementation or normal app launch occurs on main. The same earlier-source CI40347228928 is confirmed live at this checkpoint, with native tests running and strict lint failed as documented above. No second run has been dispatched.
