# Repository guidance

- Keep source code, comments, test names, commit messages, GitHub work-package descriptions, and canonical documentation in English. German belongs in localization resources and explicitly identified translation fixtures.
- Use Xcode MCP for interactive Xcode operations, including project and target creation, build settings, entitlements, builds, and native test execution. Keep projects and schemes close to Apple's templates. Do not generate Xcode projects, schemes, or test plans with Python or other scripts.
- Preserve the existing Reader implementation and its Swift packages during project migration. Do not rebuild the product from scratch.
- Prefer Swift Testing for domain, persistence, synchronization, content, intelligence, and presentation-state contracts. Keep the native XCTest/XCUIAutomation suite small and reserve it for platform behavior that code tests cannot establish.
- Use English `lowerCamelCase` function names without spaces, including test functions. Use `@Test("Readable description")` for Swift Testing display names.
- Enable Approachable Concurrency and treat compiler warnings as errors in every Reader app, test, and ReaderKit target, in Debug and Release. Keep library isolation explicit where needed; do not disable these settings to bypass failures.
- The first macOS window must open on launch without Command-N. Do not hide a failed launch by creating a window in test setup. Use stable window identities and accessibility identifiers.
- Treat external FreshRSS, PCC entitlement, physical-device, accessibility, and performance acceptance as separate evidence. Never replace these with a successful build or a mocked contract test.
- Preserve unrelated local changes, especially `iOS/Resources/Info.plist`. Remove legacy paths only after acceptance of their replacement.
