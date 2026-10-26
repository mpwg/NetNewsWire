# I: source-first structured output experiment — 2026-10-26

Status: **not adopted; selected-claim fidelity/provenance remain open**.

The previous turn made authoritative progress: policy v5's Mac selection/store boundary passes all 478 executions on 32dc1126d / CI 40314710783. This follow-up investigates remaining model quality without changing that proved shipping source. The owner retains free app-language summaries and permits selecting important statements, while every original stays linked.

## Hypothesis and protocol

The public v5 pair-1 reports show Amazon and the listed prices in both original inputs and both validated fact packets. Merchant omissions therefore occur after the facts stage in that observation. In shipping GeneratedGroup, title and summary precede sourceNumbers. The candidate moves sourceNumbers before title/summary; nothing else changes. This tests whether source selection before prose improves grounding, rather than assuming it will. Apple's [GeneratedContent initializer](https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(properties:id:)) documents schema property order requirements; it does not guarantee factuality.

Fixed before execution: existing synthetic news, conditions and offers once each, followed by the same first-six public Preisjäger group and consecutive pairs once each. There are seven configurations and no retries, new inputs or source repairs. Every run uses the actual native local model and existing trace probe with PCC disabled. No app store, account/credential, article/image transport, model tool, OCR or UI test is involved. Public corpus fingerprints/protocol remain in the [current selection receipt](i-public-feed-selection-2026-10-26.md).

Candidate generator SHA-256 `c4b82899972ed486a1242d81d5ee6f71cda83ba1629b1354cad093435670bc29`; unchanged probe SHA-256 `8d0a2c1fcdcb5293fb619a6873eb5741e0c166321343d58a3464a803ac527632`. Xcode MCP probe build 12:41:02 passes. The [complete receipt](i-source-first-experiment-2026-10-26.json) records the exact field orders, all three synthetic reports, public report hashes/errors/timings and literal merchant/price checks. Third-party prose/drafts remain local at /tmp/reader-source-first-preisjaeger-*.json. Literal mention checks diagnose omissions, not semantic correctness.

## Criteria and findings

| Criterion | Status | Evidence |
|---|---|---|
| Reliable source extraction | Open | Five of seven configurations are structurally valid; the public six-item group and final pair reject exact excerpt validation. Changing consolidation field order does not fix extraction. |
| Merchant/price and attached-condition fidelity | Open | Both synthetic offer sets retain merchant/price/restrictions; both synthetic conditions retain qualifications in this single observation. Both successful public pairs retain all four literal merchant/price combinations. These narrow successes do not prove improvement: the fact stage is stochastic and there is no fixed-facts paired consolidation comparison. News still drops Thursday. |
| Correct supporting references for selected claims | Open | News cites only news-a while asserting evening opening. news-a says Monday reopening after roof repairs and free reading-room use; it contains no evening hours. The other supplied original, news-b, contains Thursday-only evening opening, and its validated facts retain Thursday. Selecting news-a is permitted; asserting unsupported hours under that reference is not. |
| Exact shipping restoration | Fulfilled | Temporary field-order edit reversed through Xcode MCP. Generator restored byte-for-byte to v5 SHA-256 `604700192553e84b886a3a8246f2eb5631f6481745cfee8c96c1d9b57f0e260e`; probe build 12:43:46 and app/test build-for-testing 12:43:51 pass. Reader/My Mac restored; held Reader PID 24529 remains. No local app test/relaunch. |
| Full I/product acceptance | Open | Actual semantic defects remain; PCC entitlement/provisioning, final devices and owner-deferred offline/restart are still unavailable/deferred. A previous green code/native run does not prove this candidate or semantic correctness. |

The news result is consistent with information leaking across supplied packets, but the model's internal cause is not proved: it could also hallucinate the same statement. Either way the returned supporting reference is insufficient. Valid indices and per-reference numeric checks cannot establish entailment of nonnumeric claims. Merely moving references before text is not adopted as a repair.

## Next concrete investigation

Evaluate a separate selection/planning request followed by fresh drafting sessions that receive only each selected evidence group. Keep final summaries free and in the app language, preserve all originals separately, and retain independent validation. First prove the actual request boundary with controlled native executor observations; compare the known news/conditions/merchant cases in isolated real-model runs. Account for every extra request, actual schema/instruction/JSON budgets, cancellation and live consent. Do not automatically assign omitted references to prose or assume context isolation guarantees semantic correctness. Any proposed production architecture change requires review of its evidence and request/latency tradeoff before adoption.

No issue closes, validator weakens, schema/cache policy changes or new UI method is introduced by this experiment. Current shipping runtime evidence remains CI 40314710783; no unchanged native run is repeated for these documentation-only receipts.
