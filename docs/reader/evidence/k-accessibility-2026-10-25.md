# K: native Mac accessibility diagnosis — 2026-10-25

## Status

Partial correction only. K/#56 and the complete accessibility criterion remain **open**. The native XCTest accessibility audit executes successfully on this Mac; its findings are failures, not evidence of a missing runner permission.

The initial native NSHostingView exposed an unnamed accessibility group around the entire Reader window. Naming a nested SwiftUI Group did not name that outer container. Reader now uses a context-local NSViewRepresentable anchor to label only its window's otherwise unnamed content view with the product name, Reader. Existing nonempty labels are preserved; the anchor is not itself an accessibility element and adds no input target. The same anchor covers the account connection surface. No global window lookup, private API or accessibility-child merging is used.

## Verification

- Native Xcode MCP build and suite selection on My Mac, macOS 27.0.1.
- ReaderAccessibilityTests: **three Swift Testing cases pass** (nil label, empty label, existing description), including an unrelated window whose label must remain unchanged. See [raw code results](k-accessibility-code-2026-10-25.json). These are direct AppKit/SwiftUI component code tests, without XCUIAutomation.
- Test discovery reports **201 enabled functions/methods, zero disabled**. This adds one parameterized code function; no UI method was added. It is not a full-plan execution result.
- The unchanged native connection/open/cancel smoke method passes after the correction. Native run: Test-Reader-2026.10.25_23-40-01-+0100.xcresult.
- Strict SwiftLint and git diff whitespace validation pass.
- The initial component fixture incorrectly required a nonempty accessibilityChildren array from an offscreen minimal SwiftUI host. That assertion failed even for an existing unmodified label. It was removed from the window-ownership test; preservation of the actual app tree is assessed separately through native diagnostic output, not inferred from that fixture. Suite-level selection is required to execute all three parameter cases; a later individual-function selection executed only the empty-string case and is not used as three-case evidence.

## Failed audit retained

The diagnostic added performAccessibilityAudit calls to the existing connection smoke method, once before opening the form and once with it open. The collector returned false for every issue, temporarily continued after failures and attached element descriptions. No issue was filtered or marked expected. The diagnostic source is retained in [the reproduction helper](k-accessibility-audit-helper-2026-10-25.txt). It was temporary investigation instrumentation, not a previously existing CI gate; the regular smoke method is restored unchanged. Passing smoke CI does not accept the failed audit.

The six documented Mac categories were requested: contrast, elementDetection, hitRegion, sufficientElementDescription, parentChild and action. The original DerivedData result is Test-Reader-2026.10.25_23-33-50-+0100.xcresult. [Raw failed summary](k-accessibility-audit-red-2026-10-25.json).

An earlier native audit after the container correction visibly reports the root label Reader and still exposes the full split/sidebar/button tree. Its next missing-description finding is the sidebar column group rather than the outer window container. [Scoped diagnostic](k-accessibility-hosting-2026-10-25.txt); German text in this attachment is captured localized UI evidence.

Outstanding findings include unnamed split-column groups and timeline outline, contrast findings in empty states/counts and the connection surface, navigation roles, a menu action and a parent/child mismatch. Background dimming and virtual Touch Bar elements also appear and require investigation before attributing each to app code. None is silently classified as a false positive or accepted.

## Remaining acceptance

Correct and repeat the actual Mac audit on meaningful populated and empty screens, establish native action/role behavior, and perform a real VoiceOver journey. A zero-issue automated audit would still not replace VoiceOver acceptance. Final iPhone/iPad, physical devices, offline/restart, PCC, representative intelligence quality and distribution remain independent requirements.

Apple references: [accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app), [performAccessibilityAudit](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)).
