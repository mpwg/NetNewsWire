# I: newly captured public RSS text corpus — 2026-10-26

Status: **evaluation protocol fixed before inference; no acceptance or adoption**. Source is the public Preisjäger RSS endpoint, not a FreshRSS account or linked article fetch.

The HTTPS response is200, text/xml UTF-8,118767 bytes,30 items. Exactly the first six feed items are selected before inference. Four fixed configurations run once each: all six, then consecutive pairs1–2,3–4,5–6. No rerun, favorable-item selection or comparison as though this were the missing earlier corpus. [Input/source hashes, counts and transport/projection metadata](i-compact-public-rss-metadata-2026-10-26.json). Feed SHA-256 `6717d25bafcec62b533e8a4b73269215ac95144a2ba986807071615e5b389139`.

Transport has redirects disabled and5MiB/30second bounds. Only the RSS response is downloaded; no linked article/image/style/script request or code execution occurs. Preparation rejects XML DTD/entity declarations and projects description text through passive HTML tokenization, ignoring active/media/form elements and normalizing whitespace. This separate fixture projection is not acceptance of native Readability or full-article fidelity. JSON inputs fit the native probe's512KiB/32-article limits. All articles use the fixed synthetic account and false read/star state; no actual account credential or store is involved.

Raw feed, headers, projection script, six-item/pair JSON and subsequent raw drafts remain in the owner-only durable local directory `/Users/mat/.codex/artifacts/netnewswire/public-rss-20261026-6717d25bafce` (directory0700, source/input files0600). They are not committed or published; only aggregate metadata/hashes are versioned. The old temporary public corpus is absent. Reproduction uses these frozen JSON files directly, not another network fetch.

## Fixed criteria

| Criterion | Status before inference | Evidence to inspect |
|---|---|---|
| Each fixed configuration completes or retains its explicit failure | Open | Native report, exact source hashes, elapsed time and stage counts; no retry for green. |
| Every returned original key comes from its supplied input | Open | Native section keys versus input registry. Missing model coverage is reported separately; the owner's key-selection rule does not require prose to cite every original. |
| Each selected offer keeps its actual product/merchant/price relationship and source restrictions | Open | Inspect projected input and final text locally, including coupons, shipping, subscriptions and expiry qualifications when selected. Mere presence of all prices/names or source links is not entailment. |
| No invented/current-validity claim, meaningful condition change or unacknowledged mixed-language output | Open | Local source/output assessment; publish only aggregate findings/report hashes, not prose. No unvalidated model reviewer is a production gate. |
| Real FreshRSS ingestion, native HTML extraction, app UI/all-original fallback, PCC/final devices/accessibility/performance | Open and separate | This corpus does not execute those boundaries; prior named-source contracts are not relabelled. |

Candidate functional source1eb3d62c9, branch55c7c10c9, numeric helper SHA-256 `c846e19d979f950a3b918d21542c18dcfe3647288d3e8afde018c9e8f34eec7f`; generator/probe `b4d13d81d2862a4b6d28f6d2b11f6ccbc2628a5632c52481c88ec2a3cb474f25` / `d06efd78b8731aa87f7154138ad817749d83a96e6652f7b2cf3b0e5e757c1558`. Xcode MCP probe build17:28:19 succeeds. Invocation is the owned ReaderInferenceProbe with `--scenario corpus --input <frozen configuration>.json --trace --isolate --sentences --numbers`. All69 intelligence code-test functions /174 executions already pass on this source; no new code/UI test run or hosted retry is needed merely to consume new data. Source/default app remains unadopted v5 on main; restore its source/binaries after evaluation.
