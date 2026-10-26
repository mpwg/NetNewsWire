# I: explicit per-batch references — 2026-10-26

Status: **compiled candidate; current code/model acceptance open**.

Consolidation instructions now include the exact required zero-based packet IDs for each individual request, including later hierarchy rounds. Every possible list length (1–32) is token-counted; the largest instruction count is reserved before splitting prompts, without assuming tokenizer monotonicity. Existing strict reference/number/link/content validation, live consent, cancellation and bounded reduction remain unchanged. No missing reference is mechanically added to a model response. Cache policy v3 refreshes source-only/v1/v2 cards on their next generation request without deleting data or migrating schema.

Opt-in package diagnostics include the actual supplied instructions alongside prompts/drafts; the app's public generation path still has no sink. Existing native-session Swift Testing contracts now check required IDs against each hierarchy batch, trace instructions against native request instructions, and v2 cache refresh as well as the two older formats. Expected discovery: 223 code functions / 462 code executions, ten unchanged native methods / 472 total, 233 distinct. Runtime is pending; Xcode MCP app/test build-for-testing at 10:27:21 and probe build at 10:25:55, strict lint and whitespace checks pass. Held Reader PID 24529 is preserved and Reader/My Mac restored; no local tests or relaunch.

## Fixed actual-model observations

Generator SHA-256 `62608285f55c9dd2e4d4cb857b3e05a9009e30a5569a002514020458d40961bc`; probe `932bc7477247e88296f442a36a8e0d20655e2a9f574a753b3650104b02b3bc79`. [All six original reports](i-required-references-series-2026-10-26.json), ordered three offers then three long-text runs. The count was fixed before execution; every result is retained. Earlier pre-instruction-capture exploratory success is not counted in this series or relabeled with these hashes.

| Criterion | Status | Evidence |
|---|---|---|
| Two synthetic German offers | Fulfilled within these three observations | 3/3 structurally valid outputs. Both merchants/products, exact EUR 29.99/44.90, pickup/shipping/online/no-end-date conditions and stored identities remain. Minor grammar defects persist. This is narrow fixture evidence, not representative editorial acceptance. |
| Long-text factual coverage | Open | 2/3 structurally valid outputs, but both drop the September inspection/no approved opening date despite those facts appearing in the extracted evidence. Both IDs are referenced: reference coverage does not prove claim coverage. The third run produces 29 repetitive excerpts and is correctly rejected by the eight-excerpt limit. |
| Native guided collection bounds | Open | The excessive-list observation motivates native minimum/maximum collection guides while retaining independent validators. No bound repair is claimed in this source. |
| Broad quality, PCC and final platforms | Open | No representative feed, cloud authorization, device, offline or distribution acceptance follows from synthetic results. |

Next use native guided array bounds and improve preservation of distinct facts during consolidation. Preserve prior failed and superficially valid but incomplete outputs. The still-running Reader CI 40299098994 belongs to preceding 2ffe1ffe3, not this candidate; inspect that same run before another functional push.
