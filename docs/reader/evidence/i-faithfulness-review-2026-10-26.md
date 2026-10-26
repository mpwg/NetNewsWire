# I: isolated source-faithfulness reviewer — 2026-10-26

Status: **reviewer rejected as a reliable production gate; owner retains free summaries**. Production generator SHA-256 remains `9a0bdb7a20e98d35d531e14c327fc532a788342052719d8f592e933a43b1dd4e`, policy v4. No additional inference stage is installed in the app.

## Experiment

The optional ReaderInferenceProbe --scenario faithfulness evaluates eight synthetic bilingual source/summary pairs, each three times in a fresh native SystemLanguageModel session. Four pairs are unsupported (weekday omission, eligibility widening, roof restoration changed to replacement, swapped merchant price); four are supported counterparts. The model is allowed to accept omission of unselected facts, consistent with the owner's key-statement decision.

Only source/summary JSON is sent. Fixture IDs and expected labels remain outside the model input. The instructions require preservation of selected claims' dates/eligibility/restrictions/negations and treat both source/summary as untrusted data. Native greedy sampling, maximumResponseTokens=512 and an actual instruction/JSON count with 2000-token reserve are explicit. There are no model tools, app stores, credentials, article transports or PCC requests. This is an isolated feasibility experiment, not a Swift Testing/CI case or production validation.

Probe source SHA-256 `074185c078d41987364d5c1d6caf4751ff4b5483a37401b7570ebf25ad225c30`. Xcode MCP probe build at 11:26:23 and strict lint/whitespace checks pass. Reader/My Mac is restored and held normal PID 24529 remains. Local model available, context 8192. [All 24 original observations, exact inputs, instructions, native JSON responses, expected labels/errors/times](i-faithfulness-review-2026-10-26.json).

| Expected / observed | Accepted | Rejected | Error |
|---|---:|---:|---:|
| Supported statements (12 observations) | 12 | 0 | 0 |
| Unsupported statements (12 observations) | 3 | 9 | 0 |

All three false acceptances are the known missing-Thursday example. Its explanation says that the summary keeps Thursday, although that word/qualification occurs only in the source. The model therefore rationalizes the very error it should detect. The correct counterpart is also accepted. The merchant-price error is correctly rejected, but its explanation additionally mischaracterizes the faithful translation of pickup only as unsupported. An explanation is not an independent proof of entailment.

Twenty-one matching labels out of 24 observations is not representative accuracy: these are eight targeted examples with repeated greedy results, not independent random samples. Catching the other unsupported classes does not make the known missed failure acceptable. Neither prompts, deterministic sampling nor self-review establish universal factual correctness. The reviewer is not adopted as a production gate.

## Product/architecture question

The owner explicitly chose to retain free summaries in the app language and continue their quality development. Do not replace them with unchanged source-language extracts or install this reviewer as a reliable gate. The earlier key-statement/all-original-links choice remains. Preserve and improve the existing pipeline; this is not a new rebuild. Next investigate claim-specific source evidence and deterministic checks of attached conditions rather than trusting an unsupported model explanation.

## Latest fixture-only CI

Reader CI [40306422836](https://github.com/mpwg/NetNewsWire/actions/runs/40306422836) is terminal failure at **d329368b957f7eef72f69dca6d5a6990f0627806**: **475 passed / one failed of 476**, 233 passed / one failed distinct test of 234, zero skips. All 466 code executions and nine native methods pass. Only ReaderSmokeTests/testLoadedTimelineScrollingMetrics() fails its unchanged five-second removal-phase wait at ReaderUITests.swift:156, reporting Expected removed; observed Optional(removed). A post-timeout value does not prove it matched within the deadline. No root cause, relaxed deadline or service repair is claimed.

[Original summary](i-conditions-ci-summary-2026-10-26.json), [I cases and failed native case](i-conditions-ci-cases-2026-10-26.json), [recovery](i-conditions-ci-recovery-2026-10-26.json). Artifact 12642649561 ZIP SHA-256 `8b439d736faf79580dd43a41c3f146ea22b437d489c079dcb66dcf85343a8daf`. Destination arm64 My Mac VM, macOS 27.0.1 (26A434). Lint/probe/direct runner/recovery pass. Previous eaf90aea6 / CI 40304336042 remains the named all-476 pass; it is not used to erase this failure. Production/test sources are unchanged by the fixture-only addition.

Model/product acceptance, PCC authorization, real Preisjäger, final platforms, owner-deferred network-off/restart and native reliability remain open. Next continue free-summary quality work under the resolved owner choice, with production generator/validator boundaries unchanged until a candidate is verified.
