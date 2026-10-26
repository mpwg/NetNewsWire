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

The fixed next real-model series runs news, conditions, offers, quoted injection and long once each with `--trace --isolate --sentences`, retaining every outcome and source hash. No public source corpus is available for an exact-byte replay; no network, account credentials, PCC or OCR is involved. Do not retry unchanged failures for green or weaken provenance validation. Previous candidate CI40340848512 is successful on4bbf6f997 only; it cannot execute this change. Preserve the separate branch and restore main source/binaries before handoff.
