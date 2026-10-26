# I: source-literal choice candidate — policy v12

Status: **research branch, controlled Mac checks only; live-model evaluation and full acceptance pending**. Main remains policy v10 at `1d357f1a6`. The owner chose free app-language summaries plus a compact source-bound offer facts line; this candidate retains per-offer product, merchant, price and conditions from the typed prototype.

Native tokenization, sentence/clause boundaries and currency expressions build a finite set of literal source spans. A request-specific Foundation Models schema constrains each returned field to those choices. The native validator independently requires membership and exact boundaries in both fragment and whole original; it never repairs altered output. Unknown merchant/price stays nil. Literal membership cannot prove that a product, merchant, price or term has the correct semantic role, nor that all mandatory terms are present. Model output still requires explicit quality assessment.

The context calculation includes the encoded dynamic schema and prompt alongside instructions and the existing 2000-unit reserve. This is a conservative serialized-schema budget input, not a claim about the framework's exact internal prompt representation. Fragment splitting preserves all source characters and prefers whitespace boundaries. Whitespace, oversized single words and genuinely insufficient budgets must fail safely rather than authorize a clipped literal. No production context capacity or output token limit is raised; PCC remains disabled without authorization.

| Criterion | Status | Evidence |
|---|---|---|
| Literal choices, partial numeric/identifier rejection, Unicode and two independent offers | Fulfilled for controlled Mac code | Four catalog functions and native executor controls pass; invalid offers are rejected before consolidation. |
| Source identities, cache revisions, consent, cancellation and read/outbox contracts | Fulfilled for selected Mac code | Xcode MCP selection20:44:11 passes58 functions /148 executions without failures or skips. [Original summary](i-literal-offers-v12-code-summary-2026-10-26.json) and [case nodes](i-literal-offers-v12-code-cases-2026-10-26.json). |
| Actual model semantic quality and compactness | Open | Run all four unchanged public configurations once; preserve failures and results, with no retry selection. |
| Full code/native plan, strict lint and hosted CI | Open | A selected module pass is not a complete plan. |
| PCC, offline/restart, physical devices, accessibility, performance and Swift CodeQL | Open | Separate prerequisites and existing failure evidence remain. |

Original Xcode result bundle: `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.26_20-44-11-+0100.xcresult`. Earlier targeted run had three failures: two fixtures' injected character budgets could not fit the new schema and one fixed request-count fixture did not force a first reduction. The budget tests now include the actual encoded schema; their controlled character capacities are adjusted, while production limits are unchanged. The nonshrinking case forces multiple batches and asserts that the next-round generated titles never reach another request. Subsequent complete selected run passes. No issue closes.
