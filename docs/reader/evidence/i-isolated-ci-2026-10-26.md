# I: isolated-drafting native CI — 2026-10-26

Status: **initial candidate contracts fulfilled on their exact source; stable-label correction pending; no production adoption**.

## Owner-requested stopping point

The owner requested wrapping up. Stable-label CI40320201927 is now successful on 1482dadd314a86ee5603f99a195057f2c1db94f6: **488/488 executions, 478 code and ten native, 241 distinct, no failures/skips**. [Raw summary](i-isolated-stable-ci-summary-2026-10-26.json), [I cases](i-isolated-stable-ci-cases-2026-10-26.json), [recovery](i-isolated-stable-ci-recovery-2026-10-26.json). Artifact12648523570 ZIP SHA-256 `6457fc9f92d8014cca37da97d8a3df9f4a6dcf4abc576ba55cfcdb7dbb4befca`. This fulfills its controlled Mac request/label/budget/cancellation/consent contracts, not model quality or production adoption. Earlier pending statements below are historical.

A further sentence-selection checkpoint is saved only on the separate candidate branch at 251013883. Eight more functions / 21 cases compile; their runtime verification remains open. The fixed seven-model series reaches drafting in every configuration, but selected source sentences omit adjacent offer restrictions before drafting. Five outputs are structurally valid; two reject unsupported numbers/links. It is not adopted. [Exact checkpoint](https://github.com/mpwg/NetNewsWire/blob/251013883/docs/reader/evidence/i-sentence-selection-checkpoint-2026-10-26.md).

Main is restored to v5 source and binaries. Xcode initially retained the removed candidate source file in its package graph; a temporary newline in Package.swift, changed/reversed through Xcode MCP, refreshes that graph. The manifest has no diff. Main probe build13:24:54 and app/test build13:24:58 succeed; Reader/My Mac is restored and held PID24529 remains. No local app tests/relaunch occur. Work is paused at the owner's request; full #45/#54 acceptance, semantic quality, PCC, final devices and deferred offline/restart remain open.

The previous goal turn made concrete progress by implementing and compiling the isolated candidate, correcting its observed label protocol, recording fourteen fixed model observations, committing both candidate states, and restoring main's v5 source/binaries. This turn preserves actual native runtime evidence rather than treating compilation or model outputs as code-test execution.

## Initial candidate source

[Reader CI 40318608194](https://github.com/mpwg/NetNewsWire/actions/runs/40318608194) succeeds on **9766c3e1238574d3bb1937a2446b2e9e50226e99**, branch codex/reader-isolated-context. It runs **488/488 executions: 231 Swift Testing functions in 34 suites / 478 code executions plus ten native methods**, 241 distinct tests, no failures/skips. Native destination arm64 My Mac virtual machine, macOS 27.0.1 (26A434). Lint, isolated-probe build, runner failure propagation and process recovery pass.

All six new functions / ten executions pass: actual selected-only draft requests and original identity; three invalid plans; two invalid draft indices/prices; live-consent revocation; cancellation after selection; and two actual instruction-budget cases. Existing app, store, generation and native UI contracts pass. This proves the initial candidate's reindexed request protocol, not the later stable-label correction or semantic correctness.

[Raw summary](i-isolated-initial-ci-summary-2026-10-26.json), [I/native case nodes](i-isolated-initial-ci-cases-2026-10-26.json), [process recovery](i-isolated-initial-ci-recovery-2026-10-26.json). Artifact 12648227663 ZIP SHA-256 `9870688bc48f59c4c84069ad185114d61ffde858ed859176ba7fb26ad6f44cab`. The exact raw artifact is downloaded and checked before dispatching the changed-source follow-up. Earlier UI/service failures remain preserved; this green run is not evidence of their repair and is not relabeled as production acceptance.

## Corrected stable-label source

The changed source is **1482dadd314a86ee5603f99a195057f2c1db94f6**. [Reader CI 40320201927](https://github.com/mpwg/NetNewsWire/actions/runs/40320201927) is independently confirmed live on that exact commit. It follows completion/preservation of the initial handle; it is not an unchanged retry for green. The source/test change retains selected packet labels and explicitly rejects references outside that selected label set before validating content against the batch. The positive test now returns packet1 and observes the same label in the actual selected-only request. The first run cannot prove this changed predicate or request format.

| Criterion | Status | Evidence |
|---|---|---|
| Initial selected-only request, identity, invalid output, budgets, cancellation/consent | Fulfilled on initial Mac candidate | All six functions / ten cases pass in CI 40318608194. |
| Stable-label request/identity and independent subset guard | Open | New source builds, but CI 40320201927 is still live; inspect its own summary/cases before updating. |
| Existing default-path/store/native tests on corrected source | Open | Previous green candidate/main runs are not proof of changed-source runtime. |
| Actual free-summary/fact-extraction quality | Open | Fourteen retained observations include omitted conditions/merchants, rejected references and exact-excerpt failures. One correct Thursday observation is not representative fidelity. |
| Main isolation and restoration | Fulfilled | Main has no candidate source changes. Xcode MCP main probe build 13:02:02 and app/test build 13:02:09 restore generator/probe bytes to the named v5 hashes; held Reader PID 24529 remains and no local app tests/relaunch occur. |
| Adoption/PCC/final devices/offline/accessibility/performance/distribution | Open | No candidate merge or full acceptance. Missing managed PCC authorization, final-device proof and owner-deferred actual network-off/app restart remain explicit. |

## Continuation

Inspect the same corrected-source CI handle and preserve actual results. Keep main at proved v5; do not merge the research option while actual quality is insufficient. The candidate's extra requests cannot repair source-fact failures that happen before selection/drafting. The next implementation investigation should address exact source-text selection without relaxing numeric/punctuation/provenance checks, with independent native code tests before any further quality claim. Existing native sentence-index experiments provide a bounded starting point, not adoption evidence.

[Immutable candidate source/criteria and both complete model series](https://github.com/mpwg/NetNewsWire/blob/1482dadd314a86ee5603f99a195057f2c1db94f6/docs/reader/evidence/i-isolated-context-candidate-2026-10-26.md) · [Main v5 proof and public corpus](i-public-feed-selection-2026-10-26.md) · [Preceding source-first counterexample](i-source-first-experiment-2026-10-26.md).
