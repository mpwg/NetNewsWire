# Preserve independent summaries after a rejected section — 2026-10-27

The previous guard rejected an entire generated response when any section contained a recognized item-condition upgrade or unsupported evening-weekday claim. That protected originals but unnecessarily removed unrelated permitted free summaries. The actual one-section local-model sample remains an originals-only failure; this change does not invent a safe section for it.

The native generator now retains independently permitted sections and represents rejected sections with a deduplicated originals-only section. It still throws when no section survives. The coordinator independently validates structure and source-owned facts before applying the same per-section guards, retains permitted sections, and adds an existing localized invalid-response warning when a section is rejected or an originals-only section is present. Missing original identities still receive the existing originals-only fallback. Even when a permitted and a rejected section reference the same source, the rejection remains visible through a warning and an originals-only section. Existing localizations and read/outbox behavior remain; no model prompt or service is changed.

These guards reject only named lexical counterexamples. A retained section has passed structural, numeric/source and specific guard checks; it is not thereby proved factually correct. Other merchant, price, condition, time and negation errors remain possible. The user-selected free summaries and source links remain; broad semantic quality and compact offer-field attribution are open.

| Criterion | Status | Evidence |
|---|---|---|
| Reproduce total-loss and independent-publication behavior | Fulfilled | Before the correction, the controlled generator and coordinator cases both failed because the safe section was lost: 137 passes/two failures in Xcode MCP `Test-Reader-2026.10.27_12-08-17-+0100.xcresult`. |
| Warn when a rejected claim shares an original with a safe claim | Fulfilled | The initial partial-filter candidate silently omitted the rejected section when the same source remained covered; a dedicated test failed before the originals-only marker and warning were added. Xcode MCP `Test-Reader-2026.10.27_12-09-36-+0100.xcresult`. |
| Preserve permitted sections and warn for rejected originals | Fulfilled for controlled cases | Two generator cases and four actual in-memory coordinator/store cases cover distinct and shared source identities, staged and independent generators, visible warning, originals-only section, displayability and unchanged article/outbox state. The all-rejected cases continue to exercise the warned-originals path. |
| Current Mac code suite and lint | Fulfilled | 600 code executions, zero failures/skips via Xcode MCP; strict SwiftLint 0.65.1 and whitespace checks pass. [Code receipt](i-partial-guarded-sections-code-result-2026-10-27.json). |
| Actual new-model mixed output, full native UI and current hosted plan | Open | Controlled model output does not prove a real model produces useful independent sections. The old actual single-section response is still rejected. The previously observed VoiceOver instability, real-feed UI, PCC, devices, owner-deferred offline and broader semantics remain separate. |

No package closes at this checkpoint.
