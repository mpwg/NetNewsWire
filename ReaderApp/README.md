# Superseded Reader project infrastructure

The current application and tests use the native Apple-template project at **`../Reader/Reader.xcodeproj`**, created and maintained through Xcode MCP. The existing ReaderKit implementation is preserved.

Do not regenerate the root Reader.xcodeproj or use this directory as the current build entry point. These files are retained temporarily pending hosted CI acceptance and preservation of user changes. Native Release/configuration checks have passed. See the [Reader guide](../ReaderKit/README.md), [native project](../Reader/README.md) and [acceptance matrix](../docs/reader/acceptance.md).
