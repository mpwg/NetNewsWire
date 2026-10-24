"""The aggregate runner must execute every platform and propagate its failure."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReaderRunnerTests(unittest.TestCase):
    def run_runner(self, failure, action="test-without-building"):
        with tempfile.TemporaryDirectory(prefix="reader-runner-test-") as directory:
            folder = Path(directory)
            fake = folder / "xcodebuild"
            fake.write_text("""#!/bin/bash
printf '%s\\n' "$*" >> "$READER_TEST_CALLS"
if [[ "$*" == *"$READER_TEST_FAILURE_ACTION"* && "$*" == *"$READER_TEST_FAILURE"* && -n "$READER_TEST_FAILURE" ]]; then
    exit 73
fi
""")
            fake.chmod(0o755)
            log = folder / "calls"
            env = {**os.environ, "READER_XCODEBUILD": str(fake), "READER_RESULTS_DIR": str(folder / "results"),
                   "READER_SKIP_SIGNATURE_CHECK": "1",
                   "READER_IOS_DESTINATION": "platform=iOS Simulator,id=iphone-test",
                   "READER_IPAD_DESTINATION": "platform=iOS Simulator,id=ipad-test",
                   "READER_TEST_CALLS": str(log), "READER_TEST_FAILURE": failure,
                   "READER_TEST_FAILURE_ACTION": action}
            result = subprocess.run(["bash", str(ROOT / "scripts/test-reader.sh"), "all"], env=env,
                                    capture_output=True, text=True, check=False)
            return result, log.read_text()

    def test_all_platforms_really_execute(self):
        result, calls = self.run_runner("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls.count("test-without-building"), 3)
        self.assertIn("iphone-test", calls)
        self.assertIn("ipad-test", calls)
        self.assertEqual(calls.count("-project Reader/Reader.xcodeproj"), 6)
        self.assertNotIn("-testPlan", calls)
        self.assertTrue(all("-parallel-testing-enabled NO" in line
                            for line in calls.splitlines() if "test-without-building" in line))
        self.assertIn("Reader checks passed: all", result.stdout)

    def test_failures_preserve_other_platform_results_and_have_no_overall_success(self):
        for failure in ("platform=macOS", "iphone-test", "ipad-test"):
            with self.subTest(platform=failure):
                result, calls = self.run_runner(failure)
                self.assertEqual(result.returncode, 73)
                self.assertEqual(calls.count("test-without-building"), 3)
                self.assertIn("Reader checks failed:", result.stderr)
                self.assertNotIn("Reader checks passed: all", result.stdout)

    def test_build_failure_prevents_testing_stale_products_but_keeps_other_platforms(self):
        result, calls = self.run_runner("iphone-test", action="build-for-testing")
        self.assertEqual(result.returncode, 73)
        self.assertEqual(calls.count("build-for-testing"), 3)
        self.assertEqual(calls.count("test-without-building"), 2)
        self.assertFalse(any("iphone-test" in line and "test-without-building" in line
                             for line in calls.splitlines()))
        self.assertIn("ipad-test", calls)
        self.assertNotIn("Reader checks passed: all", result.stdout)


if __name__ == "__main__":
    unittest.main()
