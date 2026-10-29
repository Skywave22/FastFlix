import base64
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("prepare_android_release.py").resolve()


class PrepareAndroidReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "android").mkdir()
        (self.root / "temp").mkdir()
        self.client_env = (
            "TMDB_API_KEY=public-client-key\n"
            'FLIXQUEST_API_URL="https://streams.example.test" # public endpoint\n'
            "LARAVEL_API_URL=https://api.example.test\n"
            "MIXPANEL_API_KEY=\n"
        )
        self.secrets = {
            "RUNNER_TEMP": str(self.root / "temp"),
            "FLIXQUEST_ENV": self.client_env,
            "ANDROID_KEYSTORE_BASE64": base64.b64encode(b"test-keystore").decode(),
            "ANDROID_STORE_PASSWORD": "store password:with\\special=characters",
            "ANDROID_KEY_PASSWORD": "key-password",
            "ANDROID_KEY_ALIAS": "release alias",
        }

    def run_prepare(self, **changes):
        env = os.environ.copy()
        env.update(self.secrets)
        env.update(changes)
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_creates_private_files_and_escapes_java_properties(self):
        # Restrict permissions even when a file was already present.
        env_path = self.root / ".env"
        env_path.write_text("old")
        env_path.chmod(0o666)
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        keystore = self.root / "temp" / "flixquest-release-keystore.jks"
        properties = self.root / "android" / "key.properties"
        self.assertEqual(keystore.read_bytes(), b"test-keystore")
        self.assertEqual(env_path.read_text(), self.client_env)
        self.assertIn(
            r"storePassword=store\ password\:with\\special\=characters",
            properties.read_text(),
        )
        self.assertIn(r"keyAlias=release\ alias", properties.read_text())
        for path in (keystore, properties, env_path):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        for secret in self.secrets.values():
            self.assertNotIn(secret, result.stdout + result.stderr)

    def test_java_properties_support_unicode_aliases(self):
        result = self.run_prepare(ANDROID_KEY_ALIAS="rélease 🔐")
        self.assertEqual(result.returncode, 0, result.stderr)
        properties = (self.root / "android" / "key.properties").read_text()
        self.assertIn(r"keyAlias=r\u00e9lease\ \ud83d\udd10", properties)

    def test_rejects_missing_secrets_and_bad_base64_before_writing_files(self):
        for changes, message in (
            ({"ANDROID_KEY_ALIAS": ""}, "ANDROID_KEY_ALIAS"),
            ({"ANDROID_KEYSTORE_BASE64": "@@"}, "not valid base64"),
        ):
            with self.subTest(changes=changes):
                result = self.run_prepare(**changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertFalse((self.root / ".env").exists())

    def test_rejects_missing_config_and_emulator_urls(self):
        for client_env in (
            self.client_env.replace("MIXPANEL_API_KEY=\n", ""),
            self.client_env.replace("TMDB_API_KEY=public-client-key", "TMDB_API_KEY="),
            self.client_env.replace("https://api.example.test", "http://10.0.2.2:8000"),
            self.client_env.replace(
                "https://streams.example.test", "http://localhost:8000"
            ),
            self.client_env.replace("https://api.example.test", "https://${BACKEND}"),
            self.client_env.replace("https://api.example.test", '"unclosed'),
            "LARAVEL_API_URL=http://10.0.2.2:8000\n" + self.client_env,
        ):
            with self.subTest(client_env=client_env):
                result = self.run_prepare(FLIXQUEST_ENV=client_env)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / ".env").exists())


if __name__ == "__main__":
    unittest.main()
