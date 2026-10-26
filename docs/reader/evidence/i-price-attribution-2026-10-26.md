# I: source-first price-attribution diagnostic

Status: **research only; four of six synthetic cases pass and two fail**. Main remains v10; no offer prototype is integrated. This diagnostic asks the local model directly to extract each source amount, its source-named subject, and whether the amount is an offer price, a separate qualifying purchase, a comparison price or unknown. It does not ask a second model to review generated prose and is not a production verifier.

The native Swift Testing run at21:08:07 on macOS27.2 /26B123 uses the on-device model, a fresh session per case and greedy sampling. Six fixed synthetic inputs cover a simple offer, free entry requiring a paid newspaper, an explicitly identified German translation of that case, a paid ticket plus a required paid newspaper, current/previous prices, and two differently priced products. Each extracted amount and subject must occur literally in its own source; expected amount, role and item are checked together. No unchanged case is retried.

| Synthetic case | Observed outcome |
|---|---|
| Single current offer price | Pass: amount, item and offer role match. |
| Free entry with paid newspaper, English | Fail: the model names the newspaper as subject but classifies its amount as an offer price, even though the entry itself is free. |
| Free entry with paid newspaper, German translation | Fail: the model gives the qualifying role but changes the exact case of the source phrase naming the newspaper. The source-membership guard correctly rejects the changed spelling. |
| Paid entry plus required newspaper | Pass: ticket and qualifying newspaper prices are assigned separately. |
| Current and previous price | Pass: current and comparison roles match. |
| Two products | Pass: both prices and subjects match. |

[Original summary](i-price-attribution-2026-10-26-summary.json) · [all case nodes](i-price-attribution-2026-10-26-cases.json) · [six synthetic raw model responses](i-price-attribution-2026-10-26-responses.json). Original bundle: `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.26_21-08-07-+0100.xcresult`. The source fixture and diagnostic remain on `codex/reader-price-attribution`; strict SwiftLint0.65.1 and the test-target build pass. A first compilation required the private suite to match its private parameter type; it was corrected before the recorded run.

The English failure suggests that an independently source-bound price subject can expose this observed mismatch if it is compared with the offered product, even when the role label is wrong. It does not prove that the model will always name the right subject or that a string comparison can establish semantic identity across all writing styles. The German failure also shows unconstrained copied subject text cannot be accepted without exact source validation. A future candidate must evaluate supported and unsupported relationships, legitimate differing subject phrasing, no-price cases, conditions and real public inputs; it must fail safely on ambiguity. Do not promote this diagnostic or the previously unreliable self-review experiment to a production semantic gate. PCC, real-device/offline/accessibility/performance/CodeQL and full product acceptance stay open; no issue closes.
