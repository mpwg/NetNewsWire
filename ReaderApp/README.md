# Superseded Reader project infrastructure

The current application and tests use the native Apple-template project at **`../Reader/Reader.xcodeproj`**, created and maintained through Xcode MCP. The existing ReaderKit implementation is preserved.

Use the native project as the current build entry point. The superseded Python generator has been removed after successful native Mac/iPhone/iPad CI at f5f502957; no active script or workflow references it. The old project/Info.plist remain to preserve user edits until retirement in K; neither is an active build input. Native Release/configuration checks have passed, and the shared native scheme's Debug launch default was saved through Xcode on 2026-10-25. A recoverable local patch/archive is recorded in [native evidence](../docs/reader/evidence/native-2026-10-24.md). See the [Reader guide](../ReaderKit/README.md), [native project](../Reader/README.md) and [acceptance matrix](../docs/reader/acceptance.md).
