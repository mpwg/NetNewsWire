#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
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

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
}
#endif
