# H: native macOS OPML file export

This follows the accepted service/server contract in [H evidence](h-opml-2026-10-25.md). It exercises the actual application menu, native Save panel and sandbox file write, which were outside that earlier journal. #53 is reopened until the final current-source regression is confirmed. #39's accepted replacement contract and the owner's complete-initial-refresh publication policy are unchanged.

## Reproduction and correction

The same native `ReaderSmokeTests.testOPMLExportUsesNativeSavePanel()` runs through Xcode MCP on macOS 27.0.1, Xcode 27.1, My Mac. It launches the existing synthetic timeline, selects Export OPML, enters a filename, navigates through the system Go to Folder sheet to a unique directory owned by the test runner, verifies the selected directory, confirms Export, and reads nonempty OPML bytes from that exact destination. Teardown removes only that directory. No FreshRSS mutation or existing user document is involved.

At 22:09:45, Read/Write user-selected-file access passes the complete journey. At 22:10:35, restoring the previous Read Only capability makes the same method fail because the native Save panel never appears. Restoring Read/Write passes again at 22:11:16. [Read Only failure](h-file-export-readonly-2026-10-25.json) · [final Read/Write result](h-file-export-readwrite-2026-10-25.json).

The only product change is Xcode's User Selected File capability, edited through Xcode MCP. App Sandbox and outgoing-network access remain enabled. There is no broad folder permission, executable-file permission or sandbox exception added. Apple's [user-selected Read/Write entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write) covers this standard Open/Save-panel access. Signed test-app inspection confirms the selected capability; XCTest's separate injected read-only/test-manager exceptions are instrumentation, not a shipping write grant.

## Harness limits

The initial [wrong-locator failure](h-file-export-locator-red-2026-10-25.json) searched for Save instead of Export. A later unscoped Cancel query selected a Touch Bar control. Neither is independent evidence of a product defect. The final method scopes controls to `save-panel`, `saveAsNameTextField`, `GoToWindow`, `PathTextField` and `OKButton`; it uses public XCUIAutomation without screen coordinates or private APIs.

Default Folder X is installed locally. With it running, one native typing event times out; without it, the same dialog controls can be exercised. For the controlled comparison and final local regression, the helper is temporarily quit and always restarted afterward. This is an environment condition, not proof of a general compatibility defect. No permanent helper preference or personal-utility workaround is added to the app, tests or CI. Whole dialog hierarchies and desktop screenshots contain unrelated directory names and remain local.

The sandboxed runner initially could not create a directory at the global `/tmp` root. The final method uses `FileManager.default.temporaryDirectory`, outside the separate Reader app container. This was a fixture correction, not a Reader write failure.

## Criteria

| Criterion | Status | Evidence |
|---|---|---|
| Actual native Save-panel export writes nonempty OPML outside Reader's container | Fulfilled locally | Final 22:11:16 run, one pass, no skips; exact target directory and bytes verified. |
| Least required sandbox capability | Fulfilled for exercised path | Read Only fails the same journey; Read/Write passes twice. App Sandbox remains enabled. |
| Business logic remains code-tested | Fulfilled | Existing Swift Testing OPML contracts are unchanged; only one system-dialog UI method is added. |
| Complete current-source regression | Open | Full native plan and hosted Reader CI pending. |
| README and acceptance matrix | Updated | Root and native README, matrix, handoff and test review link this follow-up. |

This does not accept iPhone/iPad file presentation, accessibility, actual network-off/restart, physical-device signing, model quality or PCC. Those requirements remain explicitly open with their owning packages. Swift CodeQL's pre-analysis failure remains separate under K; no check is disabled.
