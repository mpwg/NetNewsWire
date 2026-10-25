# H: native macOS OPML file export

This follows the accepted service/server contract in [H evidence](h-opml-2026-10-25.md). It exercises the actual application menu, native Save panel and sandbox file write, which were outside that earlier journal. The follow-up is accepted at **071a7aee7** after the current hosted regression passes. #39's accepted replacement contract and the owner's complete-initial-refresh publication policy are unchanged. Earlier failed checkpoints below are retained as history, not current failures.

## Reproduction and correction

The same native `ReaderSmokeTests.testOPMLExportUsesNativeSavePanel()` runs through Xcode MCP on macOS 27.0.1, Xcode 27.1, My Mac. It launches the existing synthetic timeline, selects Export OPML, enters a filename, navigates through the system Go to Folder sheet to a unique directory owned by the test runner, verifies the selected directory, confirms Export, and reads nonempty OPML bytes from that exact destination. Teardown removes only that directory. No FreshRSS mutation or existing user document is involved.

At 22:09:45, Read/Write user-selected-file access passes the complete journey. At 22:10:35, restoring the previous Read Only capability makes the same method fail because the native Save panel never appears. Restoring Read/Write passes again at 22:11:16. [Read Only failure](h-file-export-readonly-2026-10-25.json) · [final Read/Write result](h-file-export-readwrite-2026-10-25.json).

The initial product correction is Xcode's User Selected File capability, edited through Xcode MCP; the native OPML-type correction is documented below. App Sandbox and outgoing-network access remain enabled. There is no broad folder permission, executable-file permission or sandbox exception added. Apple's [user-selected Read/Write entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write) covers this standard Open/Save-panel access. Signed test-app inspection confirms the selected capability; XCTest's separate injected read-only/test-manager exceptions are instrumentation, not a shipping write grant.

## Harness limits

The initial [wrong-locator failure](h-file-export-locator-red-2026-10-25.json) searched for Save instead of Export. A later unscoped Cancel query selected a Touch Bar control. Neither is independent evidence of a product defect. The final method scopes controls to `save-panel`, `saveAsNameTextField`, `GoToWindow`, `PathTextField` and `OKButton`; it uses public XCUIAutomation without screen coordinates or private APIs.

Default Folder X is installed locally. With it running, one native typing event times out; without it, the same dialog controls can be exercised. For the controlled comparison and final local regression, the helper is temporarily quit and always restarted afterward. This is an environment condition, not proof of a general compatibility defect. No permanent helper preference or personal-utility workaround is added to the app, tests or CI. Whole dialog hierarchies and desktop screenshots contain unrelated directory names and remain local.

The sandboxed runner initially could not create a directory at the global `/tmp` root. The final method uses `FileManager.default.temporaryDirectory`, outside the separate Reader app container. This was a fixture correction, not a Reader write failure.

## Criteria

| Criterion | Status | Evidence |
|---|---|---|
| Actual native Save-panel export writes nonempty OPML outside Reader's container | Fulfilled | Local strict 22:53:03 run and current hosted method both verify chosen directory, one file, exact filename and OPML bytes. |
| Least required sandbox capability | Fulfilled for exercised path | Read Only fails the same journey; Read/Write passes twice. App Sandbox remains enabled. |
| Native OPML type preserves the explicitly selected extension | Fulfilled | Generic XML fails on the hosted VM with `.opml.xml`; the same strict method passes at 071a7aee7 and records exactly `ReaderExportProbe.opml`. |
| Business logic remains code-tested | Fulfilled | Existing Swift Testing OPML contracts are unchanged; only one system-dialog UI method is added. |
| Complete current-source regression | Fulfilled | Reader CI 40237736169 at 071a7aee7 passes all 392 executions, lint, direct runner propagation and 10000-article process recovery. Zero failures/skips; one intentional guardrail runtime warning. |
| README and acceptance matrix | Updated | Root and native README, matrix, handoff and test review link this follow-up. |

This does not accept iPhone/iPad file presentation, accessibility, actual network-off/restart, physical-device signing, model quality or PCC. Those requirements remain explicitly open with their owning packages. Swift CodeQL's pre-analysis failure remains separate under K; no check is disabled.

## Complete local regression

The unchanged current source at **43da4cc22** passes the complete native plan, started at 22:12:08: **192 Swift Testing functions in 31 suites / 384 code executions plus eight native UI methods / 392 total**, 200 distinct tests, 65 parameterized functions / 257 cases, zero failures or skips. [Raw full summary](h-file-export-all-native-2026-10-25.json). One deliberately injected Foundation Models guardrail runtime warning is preserved; compiler warnings-as-errors remain enabled. Strict lint and `git diff --check` pass. The normal Debug Reader is restored through Xcode MCP (PID 11459), and Default Folder X is running again.

Exact-source [Reader CI 40234454261](https://github.com/mpwg/NetNewsWire/actions/runs/40234454261) is still running. Separate [CodeQL 40234454149](https://github.com/mpwg/NetNewsWire/actions/runs/40234454149), Swift job 121292920151, again fails before analysis in `preload_tracer`/autobuild with exit 139. That failure is not a Reader test failure or successful security analysis.

## First hosted follow-up

Reader CI 40234454261 subsequently fails **one of 392 executions**, exclusively the new export method's fixed `.opml` output-path wait. All 384 code executions and the seven existing UI methods pass. Lint, direct runner propagation and process recovery also pass. [Failed raw summary](h-file-export-ci-red-2026-10-25.json). The video shows a regular native Export confirmation and a restored main window without an error banner afterward; it does not capture the destination's actual contents. This is not yet proof of a write failure or the exact extension produced.

The revised method enumerates the previously empty owned destination and attaches its exact filenames. It requires exactly one file with the chosen basename, an OPML/XML extension and nonempty OPML content. It no longer assumes the same automatically supplied extension across native Save-panel preferences. This preserves the actual application write and format checks; it neither bypasses the dialog nor writes the output itself. The updated local 22:27:10 run passes and its attachment records `ReaderExportProbe.opml`. [Raw focused result](h-file-export-filenames-local-2026-10-25.json) · [exact filename](h-file-export-filenames-local-2026-10-25.txt). Hosted confirmation remains pending.

The [normal Debug app's signed entitlements](h-file-export-debug-entitlements-2026-10-25.txt), inspected after a regular Xcode-MCP Run, contain only App Sandbox, user-selected Read/Write, network client and debug get-task-allow. There are no XCTest file or test-manager exceptions in that ordinary app signature.

## Explicit filename correction

[Reader CI 40235645353](https://github.com/mpwg/NetNewsWire/actions/runs/40235645353) at 5b71174c0 again passes all 384 code executions and seven existing UI methods, lint, runner propagation and recovery. The added export method finds exactly one file and verifies its basename, then fails only the assumed OPML/XML extension. Its [actual filename attachment](h-file-export-ci-filenames-red-2026-10-25.txt) proves the VM wrote `ReaderExportProbe` without an extension. [Failed raw summary](h-file-export-ci-filename-red-2026-10-25.json). The test stops before its content assertion, so this run alone does not prove the file's OPML bytes.

The previous assumption that a native panel always supplies an extension was incorrect. The final fixture explicitly enters `ReaderExportProbe.opml`, verifies that exact input and checks nonempty OPML content before asserting the exact output filename. It keeps the actual system dialog, owned destination, one-output-file check and filename attachment. There is no app workaround or format change to accommodate test assumptions. The current local 22:39:04 run passes all checks, including exact filename and OPML bytes. [Raw focused result](h-file-export-explicit-name-local-2026-10-25.json). Hosted confirmation remains pending.

## Native OPML type correction

The strict explicit-name method exposes a second product configuration defect in [Reader CI 40236561024](https://github.com/mpwg/NetNewsWire/actions/runs/40236561024) at 7d9b33590. It finds one file, reads nonempty OPML bytes and then fails because the actual name is `ReaderExportProbe.opml.xml`. [Exact filename](h-file-export-ci-type-filename-red-2026-10-25.txt) · [failed summary](h-file-export-ci-type-red-2026-10-25.json). All 384 code executions and the seven existing UI methods pass, as do lint, runner propagation and recovery. The filename assertion is retained.

The new app previously exported only `public.xml` and had no imported OPML declaration. It now declares the existing interoperable `org.opml.opml` identifier, conforming to `public.xml` with the `opml` filename tag, through Xcode MCP's AddInfoPlist action. This creates the native app's Info.plist through Xcode; there is no Python generation or direct plist/project edit. The identifier matches the original project's public-format declaration in Git history, not a resurrected legacy implementation. The `ReaderOPMLFile` writer and standard fileExporter use that specific type, while XML remains readable. No document-opening role or proprietary format is added. Apple's [type declaration guide](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app) and [importedAs initializer](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/init(importedas:conformingto:)) support this imported-format arrangement.

Native build-for-testing passes. The unchanged strict export method passes locally at 22:53:03, including exact name and OPML bytes. [Local result](h-file-export-type-local-2026-10-25.json) · [imported type in the built app](h-file-export-imported-type-local-2026-10-25.json). Hosted confirmation was pending at that checkpoint and is now fulfilled below. All serialization, import and metadata matrices remain Swift Testing; this additional boundary depends on native type registration and the actual Save panel.

## Accepted hosted result

[Reader CI 40237736169](https://github.com/mpwg/NetNewsWire/actions/runs/40237736169) passes at **071a7aee7** on macOS 27.0.1, Xcode 27.1: **192 Swift Testing functions in 31 suites / 384 code executions plus eight native UI methods / 392 total**, 200 distinct tests, 65 parameterized functions / 257 cases, zero failures/skips. [Raw summary](h-file-export-ci-native-2026-10-25.json). One deliberately injected Foundation Models guardrail runtime warning remains visible; compiler warnings-as-errors remain enabled. Strict lint and direct runner failure propagation also pass.

The final export attachment records exactly [ReaderExportProbe.opml](h-file-export-ci-filename-2026-10-25.txt). The same strict method that failed against generic XML now reads nonempty OPML bytes and passes its exact-name assertion on the hosted VM. No assertion is relaxed to accept `.opml.xml`. The app uses only the standard FileDocument/fileExporter path, its native imported type declaration and user-selected Read/Write capability. Core import/serialization/error matrices remain code tests; only one genuine system-dialog method was added.

[Current recovery report](h-file-export-ci-recovery-2026-10-25.json) verifies 10000 articles after seed PID 18476 exits -9, then recovery/reopen PIDs 18481/18822 exit 0, with exact pending revisions and two retained originals. This is process-core recovery, not the owner-deferred actual network-off/restart or complete app UI recovery. Normal local Debug Reader is restored through Xcode MCP (PID 22403); Default Folder X is running again. The ordinary app's signed entitlements remain the four documented keys without test exceptions.

Root/native README, matrix, handoff, test review and GitHub #53 record these results. H/#53 is accepted again for the exercised Mac/server and native export scope; #39 remains accepted with the superseding complete-initial-refresh decision. This is not full product acceptance. Final iPhone/iPad/signing, actual offline/restart, separate-device FreshRSS, VoiceOver/accessibility, PCC, representative model quality and broader memory/energy remain open with their owning packages.

Separate [CodeQL 40237735957](https://github.com/mpwg/NetNewsWire/actions/runs/40237735957), Swift job 121302806328, fails before analysis in preload_tracer/autobuild with exit 139; its other three language jobs pass. That remains open under K/#56. No check is disabled, and Reader CI success does not imply successful Swift security analysis.
