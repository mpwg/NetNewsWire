# I: bounded source-context preservation — 2026-10-26

Status: **research only, not adopted**. The owner resumed work after the saved stopping point. Shipping main remains policy v5.

The sentence-selection checkpoint at 251013883 loses restrictions before drafting: the selected price sentence excludes the following pickup/shipping/online conditions. The candidate now validates the returned sentence indices, then forwards the entire original bounded fragment as one verbatim evidence packet. Selection is not treated as proof that a sentence is independent. This preserves punctuation, internal whitespace, negations and adjacent paragraphs within that fragment. It does not prove preservation across context-budget splits or semantic fidelity of later free summaries. The extra selection request remains experimental; its utility is not assumed.

Two additional Swift Testing functions / seven cases cover complete fragment context for each selected sentence and rejection of empty/negative/out-of-range/excessive selections. The native controlled-executor integration checks the actual evidence supplied to ordinary and isolated consolidation, including the previously lost pickup condition. No UI tests are added. Xcode MCP app/test build at 15:32:20 and package probe build at 15:33:06 succeed. Discovery reports 251 enabled distinct tests, none disabled; the expected 516 executions (506 code, ten native) remain unexecuted until current-source CI provides runtime evidence.

Generator SHA-256 `859c5cb569331b144a1a9376d891bbcb306fe81ea538dac1d2c15502e3d95407`; helper SHA-256 `9d7b210d7a114f5eece60000917b777ed5891cecdfcdd25744c2d9da243ad138`.

| Criterion | Status | Evidence |
|---|---|---|
| Source restrictions cannot be discarded by sentence-index selection within one bounded fragment | Fulfilled on local Mac candidate | Actual helper and native executor requests pass in the current 60-function /129-execution module run. |
| Invalid indices, actual budgets, cancellation and consent | Fulfilled for controlled Mac contracts | Existing and new contracts pass in that current module run; actual PCC/external errors remain separate. |
| Free app-language summary quality and correct supporting originals | Open | Four fixed synthetic scenarios are being executed once each: news, conditions, offers and quoted injection. Retain all outcomes. |
| Shipping isolation | Fulfilled | Separate candidate branch, default flags remain false; no adoption or production cache-policy change. |
| PCC/final platforms/offline/accessibility/performance | Open | Existing external prerequisites and owner deferrals remain; no evidence substitution. |

The former held Reader PID24529 is no longer present and no workspace was open at resumption. No normal app is launched. Later focused code tests are described below. The package is opened through Xcode MCP to access its native executable scheme; no project/scheme generation occurs. The old temporary public corpus and model reports are absent, so no re-execution of those exact bytes is claimed. Committed historical hashes/results remain historical evidence. New synthetic raw reports under `/tmp/reader-context-preservation-20261026/` are saved in full below.

## Overlapping-plan follow-up

The first news/injection observations repeat assertions because the selected packet groups overlap. Before issuing independent drafts, the candidate now coalesces connected groups of packet indices. Duplicate and transitively overlapping groups become one draft; disjoint groups remain separate. All plan bounds/references are validated before coalescing; per-request budgets, current consent, cancellation and per-reference draft validation are unchanged. This does not guarantee that a single model response cannot repeat prose or misstate a claim.

Two further Swift Testing functions / seven cases verify duplicate/transitive/disjoint groups and actual native executor request count, labels and complete original identities for both verbatim and indexed extraction. Xcode MCP app/test build15:37:53 succeeds; discovery reports253 enabled distinct tests, none disabled (expected523 executions,513 code/ten native). The generator SHA-256 is now `e5fe86936d0b485fe6bc57526b63580b1c9da7bf475da1f8898f4c6083b26422`; earlier 4bbf6f997 model/CI evidence remains scoped to that earlier source.

At resumption no Reader process is present (neither the former PID nor another process named Reader). The old prohibition protected that held process; after confirming its absence, focused local native code tests are safe without app launch. Xcode MCP passes all16 targeted executions, then **all60 intelligence test functions /129 executions**, no failures/skips, at15:38:55. [Complete MCP result and exact xcresult path](i-context-local-code-2026-10-26.json). This executes the actual FoundationModels controlled executor and store/coordinator contracts; it is not a live-model/GUI/device/PCC acceptance claim. No UI test runs locally and no normal app is launched.

The changed-source probe builds through Xcode MCP at15:39:39. [All four complete follow-up model observations](i-context-coalesced-model-2026-10-26.json) run once each on4901a8577: news is a single section with Thursday and both originals; offers preserve the two merchants/prices and conditions in separate sections. The conditions output retains the conditions but mixes the English word `Tuesdays` into German. Quoted injection is labelled fictitious/nonofficial but still selects irrelevant quotation content, now without duplicate groups. The deterministic overlap defect is fixed at the tested request boundary; broader model quality is not accepted. No causal/representative quality guarantee or adoption follows from this four-case observation.

## Fixed real-model observations

Source commit `4bbf6f997e40cd81c25753bbe8973b9ec933743f`; Mac CI [40340848512](https://github.com/mpwg/NetNewsWire/actions/runs/40340848512) is confirmed live on that source. Inspect that same handle; do not restart an unchanged run. All four synthetic scenarios run once with `--trace --isolate --sentences`, with every result retained in the [complete synthetic report](i-context-preservation-model-2026-10-26.json). No public/account text or credentials are included.

| Scenario | Observed outcome |
|---|---|
| News | Structurally valid; Thursday and supporting originals preserved. Reopening/hours claims repeat across three sections. |
| Conditions | Structurally valid; Friday-only late hours and Tuesday/local-resident admission restrictions preserved. |
| Offers | Structurally valid; both exact merchants/prices and pickup/shipping/online/no-end-date conditions preserved. |
| Quoted injection | Structurally valid; false quotation is labelled false rather than obeyed, but irrelevant quotation and repair claims repeat across two sections. |

These observations prove neither causal improvement over stochastic earlier runs nor representative semantic acceptance. Full context prevents the specific pre-draft loss within a bounded fragment, but later drafting still repeats assertions and can select irrelevant content. No reliable prompt-injection or factual-fidelity gate is established. Keep this option unadopted. Next address evidence focus and overlapping draft groups without hiding conditions or accepting an unvalidated model reviewer; preserve existing source/budget/consent contracts.

## Shipping restoration and next check

Main v5 generator/probe hashes are restored exactly to `604700192553e84b886a3a8246f2eb5631f6481745cfee8c96c1d9b57f0e260e` / `8d0a2c1fcdcb5293fb619a6873eb5741e0c166321343d58a3464a803ac527632`. Xcode initially caches the removed candidate helper after branch switching; a temporary/reversed newline in Package.swift refreshes the native graph. Package.swift has no diff. Main app/test build15:43:29 and package probe build15:43:45 pass through Xcode MCP; Reader/My Mac is restored. No research source is merged. The candidate and all raw synthetic/native reports are pushed, candidate head41bebc0ac.

CI40340848512 succeeds on4bbf6f997: **516/516 executions, 241 Swift Testing functions in35 suites /506 code executions plus ten native methods,251 distinct, zero failures/skips**. arm64 My Mac VM, macOS27.0.1(26A434). SwiftLint, runner propagation, isolated-probe build and10,000-article SIGKILL/reopen recovery pass. Two expected controlled guardrail runtime warnings remain visible. This is not a repair claim for earlier native daemon failures.

[Original summary](i-context-ci-summary-2026-10-26.json), [intelligence/native case nodes](i-context-ci-cases-2026-10-26.json), [recovery report](i-context-ci-recovery-2026-10-26.json). Artifact12659527326 ZIP SHA-256 `f541b33f766ce9d25295712db566a938e1dc1d68c9ecb0d24d985ac5b4a90584` matches GitHub's digest and the downloaded bytes. Original bundle is retained at `/tmp/reader-context-ci-results/reader-results/macos.xcresult`. The result does not execute4901a8577; that source has the direct129-execution local module receipt. No unchanged retry or second run is dispatched, and no run remains pending.

Dependencies and #45/#54 stay open. Main's 478-execution v5 receipt and the stable-label candidate's 488-execution receipt remain valid only for their exact sources. Latest main CodeQL 40322436766 is terminal failure in Swift analysis; actions/python/javascript-typescript succeed. No security check is disabled.
