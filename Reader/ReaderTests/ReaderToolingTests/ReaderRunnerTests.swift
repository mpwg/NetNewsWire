#if os(macOS)
import Foundation
import Testing

struct ReaderRunnerTests {
    @Test("The aggregate runner executes every native destination")
    func aggregateRunnerExecutesEveryDestination() async throws {
        let result = try await runRunner(failure: "")
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(result.calls.filter { $0.contains("test-without-building") }.count == 3)
        #expect(result.calls.contains { $0.contains("iphone-test") })
        #expect(result.calls.contains { $0.contains("ipad-test") })
        #expect(result.calls.filter { $0.contains("-project Reader/Reader.xcodeproj") }.count == 6)
        #expect(!result.calls.contains { $0.contains("-testPlan") })
        #expect(result.calls.filter { $0.contains("test-without-building") }.allSatisfy { $0.contains("-parallel-testing-enabled NO") })
        #expect(result.stdout.contains("Reader checks passed: all"))
    }

    @Test("A failed destination preserves the other results and fails the aggregate",
          arguments: ["platform=macOS", "iphone-test", "ipad-test"])
    func destinationFailurePropagates(failure: String) async throws {
        let result = try await runRunner(failure: failure)
        #expect(result.status == 73)
        #expect(result.calls.filter { $0.contains("test-without-building") }.count == 3)
        #expect(result.stderr.contains("Reader checks failed:"))
        #expect(!result.stdout.contains("Reader checks passed: all"))
    }

    @Test("A failed build cannot test stale products or suppress another destination")
    func failedBuildCannotTestStaleProducts() async throws {
        let result = try await runRunner(failure: "iphone-test", action: "build-for-testing")
        #expect(result.status == 73)
        #expect(result.calls.filter { $0.contains("build-for-testing") }.count == 3)
        #expect(result.calls.filter { $0.contains("test-without-building") }.count == 2)
        #expect(!result.calls.contains { $0.contains("iphone-test") && $0.contains("test-without-building") })
        #expect(result.calls.contains { $0.contains("ipad-test") })
        #expect(!result.stdout.contains("Reader checks passed: all"))
    }

    private struct RunResult {
        let status: Int32
        let stdout: String
        let stderr: String
        let calls: [String]
    }

    private func runRunner(failure: String, action: String = "test-without-building") async throws -> RunResult {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("reader-runner-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fake = directory.appendingPathComponent("xcodebuild")
        let calls = directory.appendingPathComponent("calls")
        let script = #"""
        #!/bin/bash
        printf '%s\n' "$*" >> "$READER_TEST_CALLS"
        if [[ "$*" == *"$READER_TEST_FAILURE_ACTION"* && "$*" == *"$READER_TEST_FAILURE"* && -n "$READER_TEST_FAILURE" ]]; then
            exit 73
        fi
        """#
        try script.write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [root.appendingPathComponent("scripts/test-reader.sh").path, "all"]
        var environment = ProcessInfo.processInfo.environment
        environment.merge([
            "READER_XCODEBUILD": fake.path,
            "READER_RESULTS_DIR": directory.appendingPathComponent("results").path,
            "READER_SKIP_SIGNATURE_CHECK": "1",
            "READER_IOS_DESTINATION": "platform=iOS Simulator,id=iphone-test",
            "READER_IPAD_DESTINATION": "platform=iOS Simulator,id=ipad-test",
            "READER_TEST_CALLS": calls.path,
            "READER_TEST_FAILURE": failure,
            "READER_TEST_FAILURE_ACTION": action
        ], uniquingKeysWith: { _, new in new })
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let status: Int32 = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do { try process.run() } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
        process.terminationHandler = nil
        try Task.checkCancellation()
        return try RunResult(status: status,
                             stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
                             stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
                             calls: String(contentsOf: calls, encoding: .utf8).split(separator: "\n").map(String.init))
    }
}
#endif
