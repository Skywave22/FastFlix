import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from prepare_firebase_android import PACKAGE, preview_config, validate

SCRIPT = Path(__file__).with_name("prepare_firebase_android.py").resolve()


def example_config(package=PACKAGE):
    return {
        "project_info": {"project_number": "123456789123", "project_id": "example-real-project"},
        "client": [{"client_info": {
            "mobilesdk_app_id": "1:123456789123:android:1234abcde1234abcd",
            "android_client_info": {"package_name": package},
        }, "api_key": [{"current_key": "AIza" + "a" * 35}]}],
    }


class FirebaseConfigTest(unittest.TestCase):
    def test_package_and_preview_are_rejected(self):
        validate(json.dumps(example_config()))
        for candidate in (preview_config(), example_config("io.github.skywave22.fastflix"), {}, "not-json"):
            with self.subTest(candidate=candidate), self.assertRaises(ValueError):
                validate(candidate if isinstance(candidate, str) else json.dumps(candidate))

    def test_preview_never_supplies_release_and_release_overwrites_debug(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {**os.environ, "FIREBASE_ANDROID_CONFIG": json.dumps(example_config())}
            debug = root / "android/app/src/prod/debug/google-services.json"
            release = root / "android/app/src/prod/release/google-services.json"
            result = subprocess.run([sys.executable, str(SCRIPT), "preview"], cwd=root, env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(debug.read_text()), preview_config())
            self.assertFalse(release.exists())
            result = subprocess.run([sys.executable, str(SCRIPT), "release"], cwd=root, env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(debug.read_text()), example_config())
            self.assertEqual(json.loads(release.read_text()), example_config())
            self.assertNotIn(env["FIREBASE_ANDROID_CONFIG"], result.stdout + result.stderr)

    def test_release_requires_config_and_does_not_write_on_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(SCRIPT), "release"], cwd=directory,
                                    env={**os.environ, "FIREBASE_ANDROID_CONFIG": ""},
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(PACKAGE, result.stderr)
            self.assertFalse((Path(directory) / "android/app/src/prod/release/google-services.json").exists())


if __name__ == "__main__":
    unittest.main()
