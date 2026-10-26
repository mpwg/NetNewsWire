# I: bounded role catalogs — policy v14 candidate

Status: **research branch; controlled Mac checks pass, actual model and full acceptance pending**. Main remains v10. This extends rejected v13's reversible exact-source labels, while constraining distinct generated fields to separate source-derived candidate sets. It does not alter the owner's free app-language summary or the requirement to link all originals.

The experimental structural limits are80 characters for product,50 for merchant,32 for price/discount,160 for each condition and320 for a non-offer excerpt. The price catalog is drawn from source currency/discount expressions and selected free-of-charge words; an absent price can stay nil. Amounts and comparison/qualifying purchases can still be confused: a structurally eligible price is not proof of the offered price. Truncated values are never synthesized, and no missing condition is invented. The limits may exclude a long legitimate product or complete condition; that is a known recall limitation requiring evidence, not grounds to present incomplete terms as complete.

Each dynamic schema references a role-specific literal set, and the native resolver independently checks both label membership and the intended role before resolving exact original UTF-8, validating fragment and whole article. The budget includes the serialized role schemas, prompts and instructions with unchanged output/context reserves. Runtime output is rejected if a non-price value is used as a price even when it is present elsewhere in the original. These structural checks do not establish supplier identity, correct price/product pairing or complete restrictions; live semantic assessment is still required.

| Criterion | Status | Evidence |
|---|---|---|
| Field length, source membership, numeric structure and encoded identity | Fulfilled for controlled candidate | Native catalog/controlled executor tests reject oversized and wrong-role values, preserve exact original quotes and Unicode and retain nil unknowns. |
| Selected Intelligence contracts | Fulfilled for candidate Mac code | Xcode MCP21:04:17:62 functions /154 executions pass without failures/skips, including runtime-budget, source/citation, cache/read/outbox and consent/cancellation contracts. [Original summary](i-role-catalog-v14-code-summary-2026-10-26.json) · [case nodes](i-role-catalog-v14-code-cases-2026-10-26.json). SwiftLint0.65.1 strict passes. |
| Actual model roles, completeness, compactness and speed | Open | Test fixed public inputs on the named source, preserving all outcomes. The model can still select a qualifying-purchase or comparison amount. |
| Complete current code/native plan and hosted CI | Open | Selected code verification is not complete CI or device evidence. |
| PCC, physical devices, offline/restart, accessibility, performance and Swift CodeQL | Open | Existing separate prerequisites and failures remain. |

Original bundle: `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.26_21-04-17-+0100.xcresult`. The candidate does not claim full product acceptance and no issue closes. Earlier v13 output with long misassigned fields remains preserved in its own receipt; this new structural bound is not a semantic-reliability claim.
