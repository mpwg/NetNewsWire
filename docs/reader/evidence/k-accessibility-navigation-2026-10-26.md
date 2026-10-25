# K: native navigation roles and section heading — 2026-10-26

## Current result

Earlier split-column/context and targeted-contrast evidence remains in [its named checkpoint](k-accessibility-columns-2026-10-25.md); the current summary supersedes its outstanding header/role findings only where proved below.

The native sidebar retains standard SwiftUI NavigationLink and Section controls. Explicit button traits correct their navigation role metadata. The Library header's own native hosting group receives its localized description through the existing context-local anchor; its heading and children remain exposed.

The full current local Mac plan passes **401 executions: 197 Swift Testing functions / 393 code executions plus eight unchanged native UI methods**. The raw result reports 205 distinct tests, 68 parameterized functions / 264 cases, zero failures/skips and the single deliberately injected model-guardrail runtime warning. [Raw current local result](k-accessibility-navigation-local-2026-10-26.json).

Full product, K and complete accessibility/VoiceOver acceptance remain **open**.

Current-source hosted confirmation is now complete: **Reader CI 40243128791 passes at f43e3094e**, with the same 401 executions, all eight UI methods, strict lint, direct runner propagation and 10,000-article process recovery. [Current raw CI result](k-accessibility-navigation-ci-2026-10-26.json) · [Current recovery](k-accessibility-navigation-ci-recovery-2026-10-26.json). The single deliberate guardrail warning remains preserved. Later changes through 9c1bf86d8 are documentation only; tested source/test fingerprints are unchanged.

## Criteria

| Criterion | Status | Evidence |
|---|---|---|
| Native Library navigation roles | Passed for the exercised Mac scope | Before correction, public in-process metadata reports AXUnknown for Unread, All articles and Starred. Explicit isButton traits report AXButton with a button role description. The repeated unfiltered native audit removes all six Unknown role reports across the initial/form states. |
| Library header description | Passed for exercised scope | The two missing-description reports for the header disappear. Existing English/German Swift Testing component cases now require both the sidebar column and header native groups to carry the localized Library description. |
| Context, ownership and localization | Passed | All nine existing ReaderAccessibilityTests executions pass, including non-overwrite, reparenting/restoration, scope changes and actual English/German split view/header groups. No code-test function is added. |
| Actual native interactions | Passed for existing scenarios | Connection/open/cancel and keyboard multi-selection/bulk-read both pass in the focused 11-execution run, then all eight UI methods pass in the full plan. No UI method is added. |
| Full native Mac regression | Passed locally | Current 401-execution original DerivedData bundle, build, strict lint and whitespace checks pass. Normal Debug Reader is restored via Xcode MCP, PID 45000. |
| Hosted regression | Passed at current source f43e3094e | Reader CI 40243128791 passes all 401 executions, strict lint, runner propagation and 10,000-article recovery. Raw reports preserve exact source scope and the deliberate guardrail warning. |
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

## Remaining toolbar-menu action: rejected style-only workaround

An isolated owned SwiftUI Menu reports isAccessibilitySelectorAllowed(press)=true and showMenu=false for the default/explicit-button-trait variants. The native borderlessButton style reports both selectors allowed. These are selector-permission observations, not evidence that an action was invoked successfully.

Applying that public style to the actual Reader toolbar Menu does **not** repair its action audit. The repeated native run at 00:07:01 still reports both readerActions failures across the initial/form states, plus the separate virtual emoji action failure. [Raw failed result](k-accessibility-menu-style-red-2026-10-26.json). The observed toolbar item is presented with the localized More title in that experiment. Standalone control metadata is therefore insufficient to accept the toolbar implementation.

The ineffective production style and temporary audit collector are reverted through Xcode MCP. Git diff confirms no remaining source/test changes, and both tested SHA-256 values above still match f43e3094e. Normal Debug Reader is restored, PID 46765; no new UI test method or production adapter is retained. The existing 401-execution source proof remains valid. Further work must inspect the actual toolbar accessibility action mapping and verify its real assistive-technology journey. The menu criterion stays open; do not reapply this style-only experiment as a completed fix.

## Actual toolbar metadata, structural probe and interaction capability

Xcode MCP debugger inspection of the running Reader (PID 47245), paused on its main thread, confirms a native toolbar hosting view around the Reader menu. Public selector metadata reports press=true/showMenu=true on its outer AXGroup and press=true/showMenu=false on the child AXMenuButton. The process is resumed after inspection. No menu action or account mutation is invoked by this read-only metadata probe. This narrows the diagnosis to the actual toolbar hierarchy; it does not prove that VoiceOver activation succeeds or that the framework is responsible for every audit finding.

A second controlled source probe uses one ToolbarItem for the existing single Menu. Native audit at 00:13:05 still reports both readerActions failures across its two states, alongside the separate virtual emoji action failure. [Raw failed structural probe](k-accessibility-single-toolbar-red-2026-10-26.json). That ineffective change and the temporary collector are reverted. Source/test SHA-256 values above still match f43e3094e. No workaround or extra UI method is retained.

The device-interaction skill requires delegated verification. Its delegated native-Mac capability check calls DeviceInteractionStartSession with the exact native Mac destination ID from the result bundle. The tool rejects it with: Cannot select specified device. To recover, pick from a list of eligible devices. The eligible list contains only stopped iPhone/iPad simulators and no Mac. No session is created, no fallback simulator is started, and no screenshot/hierarchy capture or app/system-setting change occurs. This is a limitation of that DeviceInteraction interface, not of the working native XCTest path through Xcode MCP. Mac modifier-key support and actual VoiceOver cannot be inferred from the interface's text-entry command.

Normal Debug Reader is restored through Xcode MCP (PID 48929). A manual basic VoiceOver journey is requested from the owner: reach Library/list/article, hear content, open the Reader menu, open the connection form and verify field labels before cancelling. The response is pending; no manual acceptance is claimed. [Apple's VoiceOver commands](https://support.apple.com/en-ie/guide/voiceover/cpvokys01/mac) · [Menu navigation](https://support.apple.com/en-ae/guide/voiceover/mchlp2748/mac). Broader populated-screen, keyboard and assistive-technology criteria remain open even if this basic journey succeeds.

## Preceding hosted checkpoint

[Reader CI 40242069314](https://github.com/mpwg/NetNewsWire/actions/runs/40242069314) passes at c65a10006: **401 executions**, 197 Swift Testing functions in 32 suites / 393 code executions, all eight native UI methods, 205 distinct tests, 68 parameterized functions / 264 cases, zero failures/skips and one deliberate guardrail warning. Strict lint, direct runner failure propagation and 10,000-article SIGKILL/reopen pass. [Raw native summary](k-accessibility-ci-native-2026-10-25.json) · [Recovery report](k-accessibility-ci-recovery-2026-10-25.json).

Recovery seed PID 75694 exits -9 with 271952 WAL bytes; recovery/reopen PIDs 75698/76048 exit 0, preserving two retained originals and two pending revisions. The source fingerprint is c65a10006, not the later role/header follow-up.

Separate [Swift CodeQL 40242068996/job 121315798036](https://github.com/mpwg/NetNewsWire/actions/runs/40242068996/job/121315798036) still exits 139 in preload_tracer/autobuild before analysis with CLI 2.27.3. The other three language jobs pass; no security check is disabled. [Previously verified support constraints](k-codeql-compatibility-2026-10-25.md).

Apple's [audit guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) also requires assistive-technology workflows beyond automated audits. Real VoiceOver, owner-deferred network-off/restart, separate-device FreshRSS, final iPhone/iPad/signing, PCC, representative intelligence quality and broader load/energy/distribution criteria remain independent.
