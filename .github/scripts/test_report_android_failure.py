import unittest

from report_android_failure import annotations


class ReportAndroidFailureTest(unittest.TestCase):
    def test_extracts_and_escapes_compiler_errors(self):
        result = annotations("progress 100%\n\x1b[31mfile.dart:2: Error: bad type\x1b[0m\ncode\n")
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], "file.dart:2: Error: bad type%0Acode")

    def test_keeps_flutter_failed_test_and_assertion(self):
        log = "00:00 +1: first test\nExpected: true\n  Actual: false\n00:01 +1 -1: logo test [E]\n"
        result = annotations(log)
        self.assertTrue(any("Expected: true" in entry and "logo test [E]" in entry for entry in result))

    def test_falls_back_to_the_end_of_the_log(self):
        self.assertEqual(annotations("one\ntwo%\n"), ["one%0Atwo%25"])
        self.assertEqual(annotations(""), ["No build output was captured."])


if __name__ == "__main__":
    unittest.main()
