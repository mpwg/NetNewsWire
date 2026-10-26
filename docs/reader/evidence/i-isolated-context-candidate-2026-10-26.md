# I: isolated selected-evidence drafting candidate — 2026-10-26

Status: **candidate only; native runtime/quality review pending; not adopted on main**.

The preceding source-first experiment produced an opening-hours claim unsupported by its selected reference while another supplied packet contained the condition. This candidate separates selection from drafting. It preserves the owner's free app-language prose and important-statement selection; complete original links remain the coordinator's separate contract. Context isolation is not proof of entailment or protection from model hallucination.

## Candidate implementation

Branch codex/reader-isolated-context starts from current main 8442ea910. Existing app behavior and cache policy v5 remain the default. An opt-in package parameter isolateSelectedEvidence activates the candidate only through controlled tests and ReaderInferenceProbe --trace --isolate.

After existing verbatim facts and bounded packing, a native structured request selects 1–4 related evidence groups, each with 1–32 supplied packet indices. Independent count/range checks validate the whole plan before any draft. Each group is copied to its own subset, keeping packet labels stable within the selection round and original/account identities intact. A fresh LanguageModelSession receives only that subset and creates one free title/summary with its actual supporting references. An independent subset-membership check precedes the existing numeric/URL/nonblank/range validators. References are not assigned mechanically to model prose.

Every plan and draft checks its actual instruction/JSON count against capacity minus the existing 2,000-token reserve. Plan output is capped at 800 tokens and draft output at 1,200; existing hierarchy termination remains. Every request checks cancellation/live permission before execution and cancellation after native response/diagnostic trace. No model tools, transport, UI flow or database/schema change is added. At most five model requests replace one consolidation request per batch/round; actual quality/latency must justify that cost before adoption. Native schema overhead still uses the existing reserve, not a claimed exact total-process bound.

## Criteria

| Criterion | Status | Evidence |
|---|---|---|
| Compile and compiler/lint policy | Fulfilled | Xcode MCP app/test build-for-testing 12:54:08 and probe build 12:54:11 pass; strict SwiftLint/whitespace pass. Approachable Concurrency and warnings as errors stay enabled. |
| Actual executor receives only selected draft evidence | Open | New Swift Testing function inspects actual native executor requests, supplied packet text, remapped indices and original IDs. Compiles; execution pending. |
| Invalid plans/draft references/prices are rejected | Open | Three invalid-plan and two invalid-draft executions compile; actual runtime pending. |
| Extra-request budget, live consent and cancellation | Open | Two budget cases and consent/cancellation functions compile; runtime pending. |
| Existing default path and store semantics | Open for candidate source | Existing tests remain unchanged in behavior; candidate is opt-in, caches/schema/UI unchanged. Full candidate runtime pending; prior main v5 remains proved by CI40314710783. |
| Real-model editorial/merchant/condition quality and cost | Open | Fixed seven-configuration native series runs once each: news, conditions, offers, public first-six group, then three fixed pairs. Retain every result. No improvement is claimed before inspection. |
| Production adoption | Open | No main merge or acceptance marker. Review native contracts and actual quality/latency tradeoff first. PCC/final devices/deferred offline/restart remain independently open. |

Xcode discovery: 241 enabled distinct tests, none disabled. Expected 488 executions are 478 code plus ten unchanged native methods; these are expectations until the candidate CI actually completes. The six new functions have ten executions and use Swift Testing, not app UI automation. Held normal Reader PID24529 remains; no local app test/relaunch occurs. Reader/My Mac is restored after probe compilation.

Candidate generator SHA-256 `3e277d47a97ac1e2c9e6dd54d907d4b38352698b3c2ea5bb0ce4f4cb53fd397a`; probe SHA-256 `1ca4ff7fd36ccad1bb6dc110faa25d8da5cac6214e4ff6f45257ec6088e96aa6`. Probe reports retain actual locale, OS/context, source text, native selection/draft traces, errors, references and timing. Public third-party prose stays local, with aggregate metadata/hashes published; synthetic reports can be retained in full. No OCR, images, credentials, app store, linked-resource transport or PCC is used.

## Observed initial defect and stable-label correction

The first source at 9766c3e12 reindexed each selected subset from zero. Three real-model configurations (conditions, offers, public pair-1) reject a draft reference outside the supplied subset: a draft retains the earlier packet number. The validators correctly reject it; no alias or citation repair is introduced. The initial news output is structurally valid but still drops Thursday. Three other public configurations fail source-excerpt matching before selection/drafting.

The corrected candidate keeps original packet labels in each selected draft prompt and validates membership in that exact selected label set before normal per-reference checks. Its positive native controlled-model test selects the second packet, observes only that packet/text in the actual draft request with label 1, and returns only its original identity. Negative controls still reject unselected indices and prices. Generator SHA-256 becomes `cad0a6165642857240b312b9e82a0ca95fdee9b27f2639f7573891e320a3d68c`; probe bytes are unchanged. Xcode MCP app/test build 12:57:39, probe build 12:57:41 and final test build 13:01:05 pass, as do strict lint/whitespace. Discovery remains 241 distinct / expected 488 executions; runtime remains pending on the changed source.

[Both complete seven-configuration series](i-isolated-context-series-2026-10-26.json) retain all outcomes, with complete synthetic reports and aggregate public hashes/reference diagnostics. First-series raw reports are /tmp/reader-isolated-*.json; corrected reports are /tmp/reader-isolated-stable-*.json. This is a source correction followed by a fixed comparison series, not an unchanged retry for green.

The corrected series produces three structurally valid synthetic outputs. News retains Thursday in this observation, conditions preserve their restrictions, and both offers retain prices; the kettle summary omits Donauhandel, so offer quality is still open. All four public configurations fail exact source-excerpt validation before any plan or draft. The new request topology cannot repair those earlier fact-stage failures. No representative semantic improvement, source faithfulness guarantee or production adoption is claimed.

## Candidate CI handles

[Reader CI40318608194](https://github.com/mpwg/NetNewsWire/actions/runs/40318608194) is confirmed in progress on the initial 9766c3e1238574d3bb1937a2446b2e9e50226e99 source; lint passes and Test Reader is active. Preserve its original results before dispatching current stable-label verification. It cannot prove the corrected candidate. Workflow dispatch uses the existing macOS workflow; the GitHub connector has no dispatch tool, so the gh CLI performs this operation. No project/scheme/test-plan generation or local app test is used.

Next inspect the same initial CI handle, preserve actual results, then execute the stable-label source's ten added code cases/full existing plan. Keep the candidate isolated on its branch and main's v5 source/binaries restored for normal work. Adoption is not proposed while actual quality remains insufficient.
