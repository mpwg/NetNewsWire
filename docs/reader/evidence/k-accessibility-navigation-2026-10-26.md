# K: native navigation roles and section heading — 2026-10-26

## Native VoiceOver service — focused speech observed, container correction pending

Apple's public [XCUIVoiceOverService](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice) provides enable/disable, focus movement and actual [utterance output](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice/output/utterance). The official documentation metadata lists macOS 27.0; a temporary type/property probe builds successfully with the installed Mac SDK through Xcode MCP at 01:24:43. The probe is replaced by one concrete Mac-only native UI method, testVoiceOverAnnouncesReaderAndMovesFocus.

The initial 69f14a8c3 candidate records state, enables VoiceOver only when needed, launches the isolated empty English Reader, and captures current/forward/backward utterances. Its proper-name expectation and subsequent focused correction are evaluated separately below. All versions register XCTest teardown to restore a previously disabled service, including on test failure, with an explicit disabled-state assertion and retained restoration attachment. Restoration errors are not suppressed. No AppleScript, private selector, caption-panel scraping or accessibility-label substitution is used.

Xcode MCP build-for-testing at 01:26:43 and strict lint pass. Discovery reports 208 enabled tests, zero disabled. The first hosted execution is recorded below; it does not pass the full method or plan. The full menu/library/timeline/article journey, populated-screen and full accessibility acceptance remain open regardless of this smoke result. Existing audit findings are unchanged and unfiltered.

The previous DeviceInteraction result remains valid only for that interface: it offers no native Mac target. That does not exclude this separate XCTest API. No local tests run or VoiceOver state changes during the pending owner journey; normal Reader PID 53387 stays alive. The existing 332d7f97d documentation-receipt CI is allowed to finish before this new source is pushed.

### First actual service result at 69f14a8c3

[Reader CI 40249789414](https://github.com/mpwg/NetNewsWire/actions/runs/40249789414), job 121338966189, fails. The [unaltered native summary](k-voiceover-first-ci-red-2026-10-26.json) records 403 passed executions and two failures, zero skips: all 395 code executions and eight UI methods pass; the new VoiceOver assertion fails and the following window method loses testmanagerd connectivity. Lint, runner propagation and recovery pass.

The [initial state](k-voiceover-first-initial-state-2026-10-26.txt) is disabled; enablement and nonempty/changing actual speech checks pass. The [retained utterances](k-voiceover-first-speech-2026-10-26.txt) are:

- Current: Finder Desktop group has keyboard focus
- Forward: Entries: 0 · Loaded originals: 0
- Backward: All articles empty  table

The failed assumption is that those three utterances must include the proper name Reader/Library/FreshRSS. The actual forward/backward output already names the shipping Reader counter and timeline. The initial utterance still names Finder; it is not claimed as a fresh Reader announcement. [Restoration output](k-voiceover-first-restored-state-2026-10-26.txt) confirms disabled again and the explicit teardown assertion passes.

The [scoped transport log](k-voiceover-first-transport-2026-10-26.txt) independently records a DTX/control-session disconnect at 00:39:00; the subsequent window method reports Lost connection to testmanagerd and the runner restarts. The cause is **unproved**. It is not suppressed, renamed as a passing test, or attributed to restoration without evidence. No exported matching crash report establishes a crash cause.

Further read-only inspection of the exported unified-log archive establishes the termination class: launchd's subsystem gui/501/com.apple.testmanagerd [48360] records **SIGSEGV at 00:39:00.588176 UTC**, and runningboardd independently reports that PID's termination. The [scoped original-field export](k-voiceover-first-daemon-segv-2026-10-26.json) retains those events and service chronology. disableVoiceOver is called later at 00:39:01.035051 and disabled is reported at 00:39:02.876963. Thus the daemon crash precedes the restoration call in this run. The underlying trigger/stack remains unproved; the wrong name assertion and a daemon SIGSEGV are separate observed failures. No daemon restart, test reordering, skip or crash suppression is introduced as a workaround.

The correction explicitly establishes initial keyboard focus with a native click on the hittable All articles outline, then requires VoiceOver's actual forward counter and backward timeline utterances. The click is setup, not a claim of a VoiceOver-only journey. Initial-state capture, nonempty/changing speech, registered restore/assertion and the subsequent window method remain. No deadline, tolerance, ordering, skip or expected failure is changed. Xcode MCP build-for-testing at 01:43:30 and strict lint pass; a fresh complete hosted run must prove both this method and the following window method. The same next source includes the separately compiled hitch/geometry diagnostic; neither is credited with runtime acceptance yet.

### Focused result at 87bc8cad9; container navigation still pending

[Reader CI 40250933311](https://github.com/mpwg/NetNewsWire/actions/runs/40250933311), job 121342437122, is **failed** with [404 passed executions and one failure](k-voiceover-focused-ci-red-2026-10-26.json), zero skips and one deliberate guardrail warning. All 395 code executions and all nine earlier UI methods pass, including scrolling and the following independent-window method (54.956 s). Lint, runner propagation and [process recovery](k-voiceover-focused-ci-recovery-2026-10-26.json) pass.

The [actual captured speech](k-voiceover-focused-speech-2026-10-26.txt) now begins with Reader / All articles / empty table after native focus setup. Forward speaks the exact zero-entry/original counter. Backward returns that same counter, so the strict immediate-back-to-table assertion fails. The captured partial ending of the current utterance is preserved, not completed editorially. [Initial](k-voiceover-focused-initial-state-2026-10-26.txt) and [restored](k-voiceover-focused-restored-state-2026-10-26.txt) state are false.

No lost-daemon record is found in this run's testmanagerd log. A scoped query of its exported unified-log interval from VoiceOver start through the following window method finds no matching testmanagerd SIGSEGV record. The [query scope and observations](k-voiceover-focused-transport-observation-2026-10-26.json) do not prove the earlier crash trigger is fixed; they establish that the previous transport/crash symptom is not observed in this newer interval.

The next correction retains the backward observation but does not assume it inversely crosses a native container boundary. It records current/forward/backward/parent/reentered utterances individually, calls public moveOut/moveIn, and requires the All articles parent and a reachable Reader timeline/counter after reentry. At most twenty forward navigation steps may locate the known Reader context after entering; it does not assume which child initially receives focus. Every native operation error remains a failure. Current/forward expected Reader labels, nonempty/changing speech, native focus setup and explicit state restoration remain. No test is reordered, disabled or marked expected. Native build-for-testing at 02:02:51 and strict lint pass; actual parent/reentry behavior and the complete plan still need hosted verification. This remains a scoped assistive-service case, not the full populated VoiceOver-only journey.

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
