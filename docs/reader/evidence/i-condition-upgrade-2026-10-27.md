# Known item-condition upgrade rejection — 2026-10-27

## Observed failure and correction

One separately recorded diagnostic invocation of the previously rejected explicit-condition prompt used the same frozen two-article FreshRSS input, on-device model, locale `en_AT`, macOS 27.2 / 26B123 and no cloud. The invocation completed in 14.879 seconds: two fact responses and one consolidation response, one generated section covering one original, 1,567 source-fact characters. It did not reproduce the earlier request failure, so its cause remains unknown. The generated text nevertheless upgraded the explicitly near-new item to new condition. Both observations are retained; this is not a selected successful retry or evidence of improved quality. [Aggregate and protected-input/report hashes](i-condition-upgrade-native-2026-10-27.json). The publisher text and full report remain owner-only outside Git.

The rejected prompt changes and temporary native diagnostic were removed. Production prompts remain unchanged. A new conservative English/German validation rule rejects a generated explicit new-condition claim when a referenced original states one of the recognized near-new, refurbished or used-condition forms. It checks both current display text and preserved feed text, at native-generator completion, independently before coordinator publication, and before cache reuse. Invalid new results follow the existing warned-originals path; invalid cached results regenerate. Original article/read/outbox data is preserved. No global cache invalidation or data migration is needed for this revalidated rule.

This is a narrow rejection rule, not semantic entailment. It does not detect every condition, paraphrase, price role, omitted qualification or language. Mixed-source groups and negated new-condition phrases can conservatively cause abstention; a successful result is not proof that all other claims are correct. Free app-language summaries remain available when validation permits them. Offer-field attribution, compact complete facts and representative semantic quality remain open.

## Current criteria

| Criterion | Status | Evidence |
|---|---|---|
| Reproduce known upgrade before correction | Fulfilled | New controlled seven-case test first reported four failures / three passes through Xcode MCP, `Test-Reader-2026.10.27_11-31-30-+0100.xcresult`. |
| Reject upgrades and retain supported/nonnormative controls | Fulfilled for named forms | All seven English/German cases pass in the subsequent 120-execution generator/coordinator selection. This includes preserving near-new wording and distinguishing a new model announcement. |
| Independent publication/cache validation | Fulfilled for controlled cases | Two Swift Testing store integrations prove warned originals for a new invalid result and regeneration of an invalid cached claim; source identities, article state and outbox stay unchanged. |
| Reject actual saved native failure through shipping coordinator | Fulfilled for that response | One temporary Swift Testing integration replays the saved response through the actual coordinator and in-memory store, with both originals retained, warning, unchanged article state and empty outbox; `Test-Reader-2026.10.27_11-33-39-+0100.xcresult`. No model rerun or real server/UI was used for this replay. |
| Current complete Mac code suite / lint | Fulfilled | After removing temporary diagnostics: 576 executions, zero failures/skips through Xcode MCP; strict SwiftLint 0.65.1 and whitespace pass. [Code receipt](i-condition-upgrade-code-result-2026-10-27.json). |
| Hosted CI / native UI / overall package quality | Open | Current changed-source hosted execution is still required. Earlier VoiceOver/helper failure and owner-deferred local window comparison remain separate. No real-feed app/UI, PCC, device, offline, performance or semantic acceptance follows. |

README, acceptance matrix and handoff are updated for this correction. #54 remains open.
