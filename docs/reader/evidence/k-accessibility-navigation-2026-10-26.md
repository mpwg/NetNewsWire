# K: native navigation roles and section heading — 2026-10-26

## Current result

Earlier split-column/context and targeted-contrast evidence remains in [its named checkpoint](k-accessibility-columns-2026-10-25.md); the current summary supersedes its outstanding header/role findings only where proved below.

The native sidebar retains standard SwiftUI NavigationLink and Section controls. Explicit button traits correct their navigation role metadata. The Library header's own native hosting group receives its localized description through the existing context-local anchor; its heading and children remain exposed.

The full current local Mac plan passes **401 executions: 197 Swift Testing functions / 393 code executions plus eight unchanged native UI methods**. The raw result reports 205 distinct tests, 68 parameterized functions / 264 cases, zero failures/skips and the single deliberately injected model-guardrail runtime warning. [Raw current local result](k-accessibility-navigation-local-2026-10-26.json).

Full product, K and complete accessibility/VoiceOver acceptance remain **open**.

## Criteria

| Criterion | Status | Evidence |
|---|---|---|
| Native Library navigation roles | Passed for the exercised Mac scope | Before correction, public in-process metadata reports AXUnknown for Unread, All articles and Starred. Explicit isButton traits report AXButton with a button role description. The repeated unfiltered native audit removes all six Unknown role reports across the initial/form states. |
| Library header description | Passed for exercised scope | The two missing-description reports for the header disappear. Existing English/German Swift Testing component cases now require both the sidebar column and header native groups to carry the localized Library description. |
| Context, ownership and localization | Passed | All nine existing ReaderAccessibilityTests executions pass, including non-overwrite, reparenting/restoration, scope changes and actual English/German split view/header groups. No code-test function is added. |
| Actual native interactions | Passed for existing scenarios | Connection/open/cancel and keyboard multi-selection/bulk-read both pass in the focused 11-execution run, then all eight UI methods pass in the full plan. No UI method is added. |
| Full native Mac regression | Passed locally | Current 401-execution original DerivedData bundle, build, strict lint and whitespace checks pass. Normal Debug Reader is restored via Xcode MCP, PID 45000. |
| Hosted regression | Passed on preceding source; latest source pending | Reader CI 40242069314 passes at c65a10006 before these role/header changes. The new source requires its own hosted confirmation. |
| Full accessibility and remaining K criteria | Open | Remaining diagnostic failures include contrasts, Reader-menu action, parent/child mismatch and virtual Touch Bar/emoji elements. No finding is filtered or declared a false positive. Populated-screen audit/VoiceOver and final platforms remain required. |

## Native diagnosis and repeated audit

The actual native outline rows use both the modern and older public AppKit accessibility interfaces. A diagnostic restricted to the modern protocol alone misses the row/cell path. Reading both public interfaces in the owned in-memory Reader window exposes the actual role: AXUnknown on the three Library navigation nodes, despite XCTest describing them as buttons.

Production uses the standard SwiftUI accessibilityAddTraits(.isButton), including feed/folder navigation links, and stable navigation identifiers. It adds no legacy accessibility calls. The header uses a standard explicit Section header containing Text and the existing invisible NSViewRepresentable anchor, with LocalizedStringResource resolved only at the AppKit boundary. Production never selects private class names or global windows. A direct SwiftUI grouping-only header experiment had failed and was removed at the preceding checkpoint.

The diagnostic audit at 23:55:54 on 2026-10-25 requests all six documented Mac categories and keeps every issue as a failure. [Raw failed summary](k-accessibility-navigation-audit-red-2026-10-25.json). Six Unknown role reports are gone; missing-description reports decrease from five to three, all now on virtual Touch Bar/emoji elements in the captured states. The remaining app-owned menu action and contrast failures are still recorded. This is not a green full accessibility audit.

[Focused nine-code/two-UI result](k-accessibility-navigation-focused-2026-10-25.json). An experimental unhosted fixture using public identifier getters failed to locate its five expected navigation IDs; that does not establish a product failure or absence of the complete AX tree. The experiment is removed and not counted as role-regression evidence. Current role evidence comes from actual native metadata and the unfiltered platform audit; the native header containers are additionally covered by direct component code tests. Broad populated-folder/VoiceOver coverage is not inferred.

The temporary audit collector is removed from the regular smoke method after diagnosis. Its exact helper and earlier red evidence remain linked in [the original investigation](k-accessibility-2026-10-25.md). A passing regular plan does not accept the remaining audit failures.

## Full-plan source identity and restored environment

The current local run starts at Test-Reader-2026.10.25_23-58-38-+0100.xcresult and completes after local midnight. Its tested working tree is based on c65a10006 with the committed role/header follow-up:

- ReaderWindow.swift SHA-256: 196bf3194b97137c88d44c332850f6ce57663fde94eb48ea4cab133bde411e03
- ReaderAccessibilityTests.swift SHA-256: f8fa060ee4875eb3e3552efd5072698dac747d8c791864c116ff8015a5680a44

Both fingerprints are unchanged after completion. Default Folder X was temporarily stopped for the native Save-panel scenario and restored in finally (PID 44720). It is not a permanent configuration change. Compiler warning policy, security settings and test selection are unchanged.

## Preceding hosted checkpoint

[Reader CI 40242069314](https://github.com/mpwg/NetNewsWire/actions/runs/40242069314) passes at c65a10006: **401 executions**, 197 Swift Testing functions in 32 suites / 393 code executions, all eight native UI methods, 205 distinct tests, 68 parameterized functions / 264 cases, zero failures/skips and one deliberate guardrail warning. Strict lint, direct runner failure propagation and 10,000-article SIGKILL/reopen pass. [Raw native summary](k-accessibility-ci-native-2026-10-25.json) · [Recovery report](k-accessibility-ci-recovery-2026-10-25.json).

Recovery seed PID 75694 exits -9 with 271952 WAL bytes; recovery/reopen PIDs 75698/76048 exit 0, preserving two retained originals and two pending revisions. The source fingerprint is c65a10006, not the later role/header follow-up.

Separate [Swift CodeQL 40242068996/job 121315798036](https://github.com/mpwg/NetNewsWire/actions/runs/40242068996/job/121315798036) still exits 139 in preload_tracer/autobuild before analysis with CLI 2.27.3. The other three language jobs pass; no security check is disabled. [Previously verified support constraints](k-codeql-compatibility-2026-10-25.md).

Apple's [audit guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) also requires assistive-technology workflows beyond automated audits. Real VoiceOver, owner-deferred network-off/restart, separate-device FreshRSS, final iPhone/iPad/signing, PCC, representative intelligence quality and broader load/energy/distribution criteria remain independent.
