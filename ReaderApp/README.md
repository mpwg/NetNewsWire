# Superseded Reader project infrastructure

The current application and tests use the native Apple-template project at **`../Reader/Reader.xcodeproj`**, created and maintained through Xcode MCP. The existing ReaderKit implementation is preserved.

Use the native project as the current build entry point. The superseded Python generator has been removed after successful native Mac/iPhone/iPad CI at f5f502957; no active script or workflow references it. The old project/Info.plist remain temporarily to preserve user edits while the saved Debug launch default and remaining infrastructure retirement are reconciled. Native Release/configuration checks have passed. A recoverable local patch/archive is recorded in [native evidence](../docs/reader/evidence/native-2026-10-24.md). See the [Reader guide](../ReaderKit/README.md), [native project](../Reader/README.md) and [acceptance matrix](../docs/reader/acceptance.md).
