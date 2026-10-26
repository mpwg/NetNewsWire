# I: bounded source-context preservation — 2026-10-26

Status: **research only, not adopted**. The owner resumed work after the saved stopping point. Shipping main remains policy v5.

The sentence-selection checkpoint at 251013883 loses restrictions before drafting: the selected price sentence excludes the following pickup/shipping/online conditions. The candidate now validates the returned sentence indices, then forwards the entire original bounded fragment as one verbatim evidence packet. Selection is not treated as proof that a sentence is independent. This preserves punctuation, internal whitespace, negations and adjacent paragraphs within that fragment. It does not prove preservation across context-budget splits or semantic fidelity of later free summaries. The extra selection request remains experimental; its utility is not assumed.

Two additional Swift Testing functions / seven cases cover complete fragment context for each selected sentence and rejection of empty/negative/out-of-range/excessive selections. The native controlled-executor integration checks the actual evidence supplied to ordinary and isolated consolidation, including the previously lost pickup condition. No UI tests are added. Xcode MCP app/test build at 15:32:20 and package probe build at 15:33:06 succeed. Discovery reports 251 enabled distinct tests, none disabled; the expected 516 executions (506 code, ten native) remain unexecuted until current-source CI provides runtime evidence.

Generator SHA-256 `859c5cb569331b144a1a9376d891bbcb306fe81ea538dac1d2c15502e3d95407`; helper SHA-256 `9d7b210d7a114f5eece60000917b777ed5891cecdfcdd25744c2d9da243ad138`.

| Criterion | Status | Evidence |
|---|---|---|
| Source restrictions cannot be discarded by sentence-index selection within one bounded fragment | Open | Helper and controlled-request tests compile; runtime result pending. |
| Invalid indices, actual budgets, cancellation and consent | Open | Existing and new contracts compile; previous stable-label CI does not execute this changed source. |
| Free app-language summary quality and correct supporting originals | Open | Four fixed synthetic scenarios are being executed once each: news, conditions, offers and quoted injection. Retain all outcomes. |
| Shipping isolation | Fulfilled | Separate candidate branch, default flags remain false; no adoption or production cache-policy change. |
| PCC/final platforms/offline/accessibility/performance | Open | Existing external prerequisites and owner deferrals remain; no evidence substitution. |

The former held Reader PID24529 is no longer present and no workspace was open at resumption. No app was launched or tested locally. The package is opened through Xcode MCP to access its native executable scheme; no project/scheme generation occurs. The old temporary public corpus and model reports are absent, so no re-execution of those exact bytes is claimed. Committed historical hashes/results remain historical evidence. New synthetic raw reports are retained under `/tmp/reader-context-preservation-20261026/` and will be saved with their outcomes.

## Fixed real-model observations

Source commit `4bbf6f997e40cd81c25753bbe8973b9ec933743f`; Mac CI [40340848512](https://github.com/mpwg/NetNewsWire/actions/runs/40340848512) is confirmed live on that source. Inspect that same handle; do not restart an unchanged run. All four synthetic scenarios run once with `--trace --isolate --sentences`, with every result retained in the [complete synthetic report](i-context-preservation-model-2026-10-26.json). No public/account text or credentials are included.

| Scenario | Observed outcome |
|---|---|
| News | Structurally valid; Thursday and supporting originals preserved. Reopening/hours claims repeat across three sections. |
| Conditions | Structurally valid; Friday-only late hours and Tuesday/local-resident admission restrictions preserved. |
| Offers | Structurally valid; both exact merchants/prices and pickup/shipping/online/no-end-date conditions preserved. |
| Quoted injection | Structurally valid; false quotation is labelled false rather than obeyed, but irrelevant quotation and repair claims repeat across two sections. |

These observations prove neither causal improvement over stochastic earlier runs nor representative semantic acceptance. Full context prevents the specific pre-draft loss within a bounded fragment, but later drafting still repeats assertions and can select irrelevant content. No reliable prompt-injection or factual-fidelity gate is established. Keep this option unadopted. Next address evidence focus and overlapping draft groups without hiding conditions or accepting an unvalidated model reviewer; preserve existing source/budget/consent contracts.

Dependencies and #45/#54 stay open. Main's 478-execution v5 receipt and the stable-label candidate's 488-execution receipt remain valid only for their exact sources. Latest main CodeQL 40322436766 is terminal failure in Swift analysis; actions/python/javascript-typescript succeed. No security check is disabled.
