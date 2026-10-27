#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
import ReaderPersistence
import ReaderDomain
@testable import ReaderUI

@MainActor
struct ReaderAccessibilityTests {
    @Test("Native hosting labels are window-local and preserve existing descriptions",
          arguments: [nil, "", "Existing container"] as [String?])
    func hostingLabelsPreserveWindowOwnership(initialLabel: String?) async throws {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: Text("Reader content").background {
            ReaderWindowAccessibility().accessibilityHidden(true)
        })
        host.setAccessibilityLabel(initialLabel)
        let unrelatedHost = NSHostingView(rootView: Text("Unrelated content"))
        let window = makeWindow()
        let unrelatedWindow = makeWindow()
        window.contentView = host
        unrelatedWindow.contentView = unrelatedHost
        defer {
            window.contentView = nil
            unrelatedWindow.contentView = nil
            window.close()
            unrelatedWindow.close()
        }
        host.layoutSubtreeIfNeeded()
        let expected = initialLabel?.isEmpty == false ? initialLabel : "Reader"
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while host.accessibilityLabel() != expected && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
            host.layoutSubtreeIfNeeded()
        }
        #expect(host.accessibilityLabel() == expected)
        #expect(unrelatedHost.accessibilityLabel() == nil)
    }

    @Test("Group descriptions follow their context and restore prior labels when detached",
          arguments: [nil, ""] as [String?])
    func groupLabelsFollowTheirContext(originalLabel: String?) {
        let window = makeWindow()
        let root = NSView(frame: window.contentRect(forFrameRect: window.frame))
        let first = NSView()
        let second = NSView()
        let button = NSButton(title: "Article action", target: nil, action: nil)
        first.setAccessibilityRole(.group)
        second.setAccessibilityRole(.group)
        first.setAccessibilityLabel(originalLabel)
        first.addSubview(button)
        first.setAccessibilityChildren([button])
        root.addSubview(first)
        root.addSubview(second)
        window.contentView = root
        defer { window.contentView = nil; window.close() }

        let anchor = ReaderWindowAccessibilityAnchor()
        anchor.configure(label: "Articles", scope: .nearestGroup)
        first.addSubview(anchor)
        #expect(first.accessibilityLabel() == "Articles")
        #expect(second.accessibilityLabel() == nil)
        #expect(root.accessibilityLabel() == nil)
        #expect(first.accessibilityChildren()?.first as? NSButton === button)

        anchor.configure(label: "Unread articles", scope: .nearestGroup)
        #expect(first.accessibilityLabel() == "Unread articles")
        second.addSubview(anchor)
        #expect(first.accessibilityLabel() == originalLabel)
        #expect(second.accessibilityLabel() == "Unread articles")
        #expect(first.accessibilityChildren()?.first as? NSButton === button)

        anchor.removeFromSuperview()
        #expect(second.accessibilityLabel() == nil)
    }

    @Test("An external description change is preserved during updates and detachment")
    func externalDescriptionsKeepOwnership() {
        let window = makeWindow()
        let group = NSView()
        group.setAccessibilityRole(.group)
        window.contentView = group
        defer { window.contentView = nil; window.close() }
        let anchor = ReaderWindowAccessibilityAnchor()
        anchor.configure(label: "Articles", scope: .nearestGroup)
        group.addSubview(anchor)
        #expect(group.accessibilityLabel() == "Articles")

        group.setAccessibilityLabel("External description")
        anchor.configure(label: "Updated articles", scope: .nearestGroup)
        #expect(group.accessibilityLabel() == "External description")
        anchor.removeFromSuperview()
        #expect(group.accessibilityLabel() == "External description")
    }

    @Test("Changing label scope restores the previous container before naming its replacement")
    func scopeChangesRestorePreviousContainer() {
        let window = makeWindow()
        let root = NSView()
        let group = NSView()
        group.setAccessibilityRole(.group)
        root.addSubview(group)
        window.contentView = root
        defer { window.contentView = nil; window.close() }
        let anchor = ReaderWindowAccessibilityAnchor()
        group.addSubview(anchor)
        anchor.configure(label: "Reader", scope: .windowContent)
        #expect(root.accessibilityLabel() == "Reader")
        #expect(group.accessibilityLabel() == nil)

        anchor.configure(label: "Articles", scope: .nearestGroup)
        #expect(root.accessibilityLabel() == nil)
        #expect(group.accessibilityLabel() == "Articles")
        anchor.restoreLabel()
        #expect(group.accessibilityLabel() == nil)
    }

    @Test("The actual split view exposes localized native column descriptions",
          arguments: [("en", "Library", "Article"), ("de", "Bibliothek", "Artikel")])
    func splitColumnsExposeLocalizedDescriptions(localeID: String, library: String, article: String) async throws {
        let locale = Locale(identifier: localeID)
        let store = try ReaderStore(inMemory: true)
        let services = ReaderServices(repository: store)
        let host = NSHostingView(rootView: ReaderWindow(services: services).environment(\.locale, locale))
        let window = makeWindow()
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        window.orderFront(nil)
        // Explicit English/German translation fixtures verify the ReaderUI resource bundle.
        let timeline = ReaderSession(services: services).title
        let expected = Set(["Reader", library, article, timeline])
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while (!expected.isSubset(of: Set(groupLabels(in: host))) || groupLabels(in: host).filter { $0 == library }.count < 2)
            && ContinuousClock.now < deadline {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(10))
        }
        let labels = Set(groupLabels(in: host))
        #expect(expected.isSubset(of: labels))
        #expect(groupLabels(in: host).filter { $0 == library }.count >= 2)
    }

    @Test("Hosted source facts expose literal selectable text without app UI automation",
          arguments: ["en", "de"])
    func sourceFactsExposeLiteralText(localeID: String) async throws {
        let quote = "Example Store: EUR 29.99; code SAVE5. Not valid online. [Terms](https://example.invalid)"
        let facts = DigestSourceFacts(source: ArticleKey(accountID: UUID(), remoteID: "offer"), excerpts: [quote])
        let host = NSHostingView(rootView: DigestSourceFactsView(facts: facts).environment(\.locale, Locale(identifier: localeID)))
        let window = makeWindow()
        window.setContentSize(NSSize(width: 240, height: 500))
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        window.orderFront(nil)
        let fallback = localeID == "de" ? "Angebotsdetails, falls vorhanden: Siehe Original." : "Offer details, if applicable: See original."
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        var values: [String] = []
        repeat {
            host.layoutSubtreeIfNeeded()
            values = accessibleText(in: host)
            if values.contains(quote) && values.contains(fallback) { break }
            try await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        #expect(values.contains(quote))
        print("View subtree:", viewText(in: host))
        #expect(values.contains(fallback))
        #expect(facts.excerpts == [quote])
    }

    private func viewText(in view: NSView) -> [String] {
        let own = [view.accessibilityLabel(), view.accessibilityValue() as? String].compactMap { $0 }
        return own + view.subviews.flatMap { viewText(in: $0) }
    }

    private func accessibleText(in element: any NSAccessibilityProtocol) -> [String] {
        let own = [element.accessibilityLabel(), element.accessibilityValue() as? String].compactMap { $0 }
        let children = (element.accessibilityChildren() ?? []).compactMap { $0 as? any NSAccessibilityProtocol }
        let descendants = children.isEmpty ? ((element as? NSView)?.subviews ?? []).map { $0 as any NSAccessibilityProtocol } : children
        return own + descendants.flatMap { accessibleText(in: $0) }
    }

    private func groupLabels(in view: NSView) -> [String] {
        let own = view.accessibilityRole() == .group ? [view.accessibilityLabel()].compactMap { $0 } : []
        return own + view.subviews.flatMap { groupLabels(in: $0) }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
}
#endif
