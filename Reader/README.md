# Native Reader application

Open `Reader.xcodeproj` in this directory and select the shared Reader scheme. This project was created through Xcode MCP with Apple's multiplatform SwiftUI app template. It links the six existing ReaderKit libraries; the standalone store recovery probe is not an app dependency.

ReaderTests is an unhosted Swift Testing code-test target. ReaderUITests is a small native XCTest/XCUIAutomation target. Apple's automatic scheme test plan discovers both; no generated project, scheme or test-plan script is required. Use Xcode MCP for interactive builds, tests and project changes.

The shared Reader scheme launches Debug by default. Profiling and archiving use Release. Temporary Release checks must restore and save the Debug launch configuration through Xcode afterward.

Every native target enables Swift 6, complete concurrency checking, Approachable Concurrency and Swift/C-family warnings as errors. ReaderKit applies the equivalent package settings to every target. Debug and Release use separate bundle IDs and storage namespaces. See the [Reader guide](../ReaderKit/README.md) for account setup, architecture and acceptance limits.

The UI smoke launch uses `--ui-testing` with an isolated in-memory store. It requires no personal account. The first Mac window must appear automatically, without Command-N. Selection, search, sheets and query generations belong to each scene; repository and account services are shared.

Layout follows the available window and system safe areas. Article rendering uses WebView/WebPage with content JavaScript disabled. Physical-device, iPad multiwindow, VoiceOver, Dynamic Type, keyboard, RTL and sustained-load checks require separate evidence.
