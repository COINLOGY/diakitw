"""Ensure CI never prints network identifiers from failed Android probes."""
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT=Path(__file__).resolve().parents[1]/'ci/safe-probe-summary.py'

class ProbeDiagnostics(unittest.TestCase):
    def test_failure_reports_only_class_and_source_location(self):
        raw=('INSTRUMENTATION_RESULT: stream=FAIL java.lang.AssertionError: '
             'IP=203.0.113.42 https://example.org/path user@example.org\n'
             ' at app.diakitw.EntryProbe.run(EntryProbe.java:21)\n'
             'INSTRUMENTATION_CODE: -1\n')
        with tempfile.TemporaryDirectory() as temp:
            report=Path(temp)/'report.txt'
            report.write_text(raw)
            result=subprocess.run(['python3',str(SCRIPT),str(report)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0)
        self.assertIn('java.lang.AssertionError',result.stdout)
        self.assertIn('EntryProbe.java:21',result.stdout)
        for secret in ('203.0.113.42','example.org','user@example.org'):
            self.assertNotIn(secret,result.stdout+result.stderr)

    def test_missing_pass_has_sanitized_fallback(self):
        with tempfile.TemporaryDirectory() as temp:
            report=Path(temp)/'report.txt'
            report.write_text('private IP: 198.51.100.4')
            result=subprocess.run(['python3',str(SCRIPT),str(report)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0)
        self.assertIn('reason unavailable',result.stdout)
        self.assertNotIn('198.51.100.4',result.stdout+result.stderr)

    def test_map_visibility_failure_reports_only_safe_numeric_bounds(self):
        raw=('INSTRUMENTATION_RESULT: stream=FAIL java.lang.AssertionError: '
             'Map hidden below initial viewport visible=0 total=660 '
             'IP=203.0.113.42 https://example.org user@example.org\n')
        with tempfile.TemporaryDirectory() as temp:
            report=Path(temp)/'report.txt'
            report.write_text(raw)
            result=subprocess.run(['python3',str(SCRIPT),str(report)],capture_output=True,text=True)
        self.assertIn('map visible=0/660',result.stdout)
        for secret in ('203.0.113.42','example.org','user@example.org'):
            self.assertNotIn(secret,result.stdout+result.stderr)

    def test_runner_uses_sanitized_diagnostic(self):
        runner=(SCRIPT.parent/'run-android-entry.sh').read_text()
        self.assertIn('ci/safe-probe-summary.py "$report"', runner)

if __name__=='__main__':unittest.main()
