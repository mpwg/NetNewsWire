# I: literal source quotations with token boundaries — policy v10

Status: **implemented on main and code-tested on Mac; full source CI pending**. This is an independently verified quotation-validation correction. The failed typed-offer and sentence-selection generators remain separate, and source-facts display retains its existing v7 data contract.

Plain substring matching can accept29.99 from129.99 or SAVE5 from SAVE50 as an exact source excerpt. Consolidation then treats the clipped number as source evidence. The new matcher requires literal source spelling and ASCII-token/decimal boundaries at the matched occurrence. It searches later occurrences when an earlier partial match is rejected, preserves exact decomposed Unicode and permits currency text adjacent to Japanese text. It does not normalize changed quotations, classify prices, resolve merchant/product relationships or establish semantic completeness. A whole value elsewhere in an article still does not prove its role in a selected claim.

The same matcher applies during source extraction and independent source-facts publication/cache validation. The existing v6 bracket-reference guard, numeric/source/link/content checks, bounded requests, cancellation/consent and all-original access remain. Model prompts, generation schemas and stage count stay unchanged from v7. No new model call, UI, transport or source/read/outbox action is introduced.

Policy v10 regenerates older cache fingerprints on their next generation request, including v7 and the unadopted experimental v8/v9 prefixes. Stored sources and old snapshots remain readable; no SwiftData schema migration or data deletion occurs. The controlled model fixture ends long excerpts at whitespace instead of manufacturing a clipped final word to fit its old128-character assumption.

| Criterion | Status | Evidence |
|---|---|---|
| Partial-only ASCII/numeric evidence cannot authorize a generated claim | Fulfilled for current Mac code | Ten literal matching cases and two actual native executor cases reject clipped prices/coupon codes before consolidation; exact, later-occurrence, Unicode and Japanese-adjacent currency controls pass. |
| Cached source facts use the same quotation rules | Fulfilled for current Mac code | A cached excerpt clipped from an original word is rejected and regenerated; existing foreign/empty/content/citation cases remain covered. |
| Older policies refresh without article/read/outbox changes | Fulfilled for current Mac code | All frozen earlier policy prefixes, complete original snapshots and empty outbox assertions pass. |
| Current Mac code, compiler and lint checks | Fulfilled for named boundary | Xcode MCP build19:23:15 and native code selection19:23:45 pass236 functions /511 executions, zero failures/skips. Strict SwiftLint0.65.1 and whitespace checks pass; Approachable Concurrency/warnings-as-errors stay enabled. |
| Full current hosted plan | Open | Discovery246 enabled/zero disabled is not execution; a changed-source hosted result remains pending. |
| Compact, reliable offer facts/selected free prose | Open | Typed-copy candidate0/4 public configurations and prior sentence-selection failures are preserved; neither is integrated. |
| PCC/final devices/offline/full accessibility/performance/Swift CodeQL | Open | Existing separate prerequisites/deferrals remain. |

[Original code summary](i-quotation-v10-code-summary-2026-10-26.json), [all case nodes](i-quotation-v10-code-cases-2026-10-26.json). Original bundle: `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.26_19-23-45-+0100.xcresult`.

Current generator SHA-256 `232acb3f91661f39ec31ad4ea54bdfd98a4e2f62dbe69f9301988fbe0f7712ee`; coordinator `0331b2cc8ee4866b799414577e3fdf3fb9e0f590bd4875f42f9c8de12cf75f37`. Main probe19:27:17 and app/test19:27:22 rebuild successfully through Xcode MCP; Reader/My Mac is restored. The active source has no typed-offer model/view or sentence-selection helper. Candidate code stays in Git on `codex/reader-offer-fields` /76742b1743c62c1f7ed859a423ebe8b06c1f8c8c. No normal app is launched.

The typed-source prototype is retained at `codex/reader-offer-fields`; acf4ee290 is its original tested/modelled source, with the later validation correction and534-code receipt on the branch. [Every typed-offer outcome and exact sources](i-offer-fields-v9-2026-10-26.md). All four fixed configurations reject rewritten offer values; qualifying-newspaper price assignment and per-product coupon relationships also remain wrong in the captured drafts. No source text is repaired or model result selected by retry. The local unpublished prototype commit is preserved on that branch before restoring main; no remote main history is rewritten.

No live-model semantic rerun or quality acceptance is inferred from stricter validation. Next replace copied typed field values with bounded Reader-owned source references while preserving explicit per-offer roles; another global sentence-selection prompt does not address the observed field/condition errors. Full product acceptance remains open and no issue closes.
