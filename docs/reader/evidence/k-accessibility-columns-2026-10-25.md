# K: native split-column accessibility descriptions — 2026-10-25

## Result and scope

The actual Mac split-column hosting containers now expose Library, the current timeline title, and Article. Static descriptions resolve existing ReaderUI String Catalog resources using the SwiftUI locale; feed/filter titles remain data. No new translation keys, UI methods, navigation controls or selection rules are introduced. This is a partial K/#56 correction; complete accessibility acceptance remains open.

A native diagnostic first confirmed that standard SwiftUI accessibilityElement(children: .contain) plus accessibilityLabel names inner content but leaves the outer NSHostingView groups unnamed. Production therefore extends the existing context-local public AppKit anchor. The column scope walks only its own superview chain and selects the nearest native AXGroup. It uses no private class names, global window scans or changes to accessibility children.

The anchor keeps a weak reference to the labelled container, its previous value and its own applied value. Moving to another container, switching scope, dismantling or detaching restores a label only while it is still owned by this anchor. Updates preserve externally supplied descriptions. This also strengthens the earlier window-content scope.

## Verification

Native Xcode MCP build succeeds with compiler warnings-as-errors. Strict SwiftLint and whitespace validation pass.

ReaderAccessibilityTests now has **five Swift Testing functions / nine passing executions**:

- Three original cases: nil/empty/existing hosting labels and an unaffected other window.
- Two group cases: nil/empty original labels, changing titles, reparenting, restoration and unchanged native button child identity.
- An external label update survives both reconfiguration and detachment.
- Switching between window and group scope restores the original target.
- Two actual ReaderWindow/NavigationSplitView component cases verify native group descriptions in explicit English/German translation fixtures.

[Raw code result](k-accessibility-columns-code-2026-10-25.json). These are unhosted code tests using direct AppKit/SwiftUI components, without XCUIAutomation. Discovery reports **205 enabled functions/methods, zero disabled**; this is not a full-plan execution result.

The English component case initially failed: String(localized:bundle:locale:) selected the process language while using the locale for formatting. Native comparison showed LocalizedStringResource with its explicit locale selects the intended language. Resolving that resource only at the AppKit boundary fixes both cases without manual bundle-path lookup. The failed case was corrected, not disabled.

The existing native connection/open/cancel smoke method also passes, including its outline-description assertion. [Raw smoke result](k-accessibility-columns-smoke-2026-10-25.json). No UI method was added.

## Repeated diagnostic remains failed

The six-category native Mac audit was repeated at 23:43:48 with all findings retained as failures. [Raw failed summary](k-accessibility-columns-audit-red-2026-10-25.json). Missing-description findings drop from thirteen to five across the two audited states; contrast/unknown-role findings remain. This is progress on the identified containers, not a zero-issue accessibility audit.

The scoped native hierarchy shows Reader on the outer host and the localized Library label on the sidebar column, with its outline/header/navigation controls still exposed. [Captured localized UI diagnostic](k-accessibility-columns-hosting-2026-10-25.txt). The two code component cases independently verify all three column labels. The later explicit-locale correction is covered by the English/German component cases; the audit captured the ordinary German app environment before that correction.

The remaining unnamed app group is the Library section header. Virtual Touch Bar/emoji elements, contrast including dimmed background content, standard NavigationLink roles, the Reader menu action and a parent/child mismatch still need diagnosis. No remaining finding is filtered or accepted as a false positive.

The temporary audit collector is restored out of the regular smoke method after diagnosis, as at the earlier checkpoint. Its failed evidence remains versioned. Existing Reader CI continues to run every enabled regular test; this follow-up's hosted result is pending at commit time. Real VoiceOver, populated-screen audits and final platform requirements remain open.
