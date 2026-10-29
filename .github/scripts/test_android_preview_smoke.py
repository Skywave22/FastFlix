"""Regression checks for the disposable Android preview startup probe."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('android_preview_smoke.sh')
PACKAGE = 'io.github.skywave22.fastflix'


class PreviewSmokeTests(unittest.TestCase):
    def run_probe(self, window, *, logs='', airplane_mode='1'):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        bin_dir = root / 'bin'
        bin_dir.mkdir()
        fake_adb = bin_dir / 'adb'
        fake_adb.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
args = sys.argv[1:]
with open(os.environ['ADB_TRACE'], 'a') as trace:
    trace.write(' '.join(args) + '\\n')
if args and args[0] == 'pull':
    target = Path(args[2])
    target.write_text(os.environ['MOCK_WINDOW'] if args[1].endswith('.xml') else 'image')
elif args[:4] == ['shell', 'settings', 'get', 'global']:
    print(os.environ['MOCK_AIRPLANE_MODE'] if args[4] == 'airplane_mode_on' else '0')
elif args[:2] == ['logcat', '-d']:
    print(os.environ['MOCK_LOG'])
''')
        fake_adb.chmod(0o755)
        fake_sleep = bin_dir / 'sleep'
        fake_sleep.write_text('#!/bin/sh\nexit 0\n')
        fake_sleep.chmod(0o755)
        trace = root / 'adb.trace'
        env = {
            **os.environ,
            'PATH': str(bin_dir) + os.pathsep + os.environ['PATH'],
            'RUNNER_TEMP': str(root),
            'ADB_TRACE': str(trace),
            'MOCK_WINDOW': window,
            'MOCK_LOG': logs,
            'MOCK_AIRPLANE_MODE': airplane_mode,
        }
        result = subprocess.run(
            ['bash', str(SCRIPT), 'preview.apk'],
            env=env, capture_output=True, text=True, timeout=30,
        )
        return result, trace.read_text().splitlines()

    def test_grants_notification_permission_before_checking_app_content(self):
        result, calls = self.run_probe(
            f'<hierarchy><node package="{PACKAGE}" content-desc="FastFlix"/></hierarchy>'
        )
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn('reached accessible Android app content', result.stdout)
        grant = calls.index(f'shell pm grant {PACKAGE} android.permission.POST_NOTIFICATIONS')
        launch = next(i for i, call in enumerate(calls) if call.startswith('shell am start'))
        self.assertLess(grant, launch)

    def test_system_dialog_does_not_count_as_accessible_app_content(self):
        result, _ = self.run_probe(
            '<hierarchy><node package="com.google.android.permissioncontroller" '
            'text="Allow notifications"/><node package="' + PACKAGE + '" text=""/></hierarchy>'
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No accessible app content appeared', result.stdout)

    def test_does_not_launch_if_airplane_mode_cannot_be_enabled(self):
        result, calls = self.run_probe('<hierarchy/>', airplane_mode='0')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Could not verify the emulator is offline', result.stdout)
        self.assertFalse(any(call.startswith('install ') for call in calls))

    def test_fatal_error_is_reported_even_if_app_content_was_visible(self):
        result, _ = self.run_probe(
            f'<hierarchy><node package="{PACKAGE}" text="FastFlix"/></hierarchy>',
            logs='FATAL EXCEPTION: main',
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Android reported a fatal startup exception', result.stdout)


if __name__ == '__main__':
    unittest.main()
