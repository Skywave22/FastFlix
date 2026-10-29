import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from prepare_android_preview import prepare
from prepare_android_release import dotenv_values

SCRIPT = Path(__file__).with_name('prepare_android_preview.py').resolve()
EXAMPLE = 'TMDB_API_KEY=\nFLIXQUEST_API_URL=\nLARAVEL_API_URL=http://10.0.2.2:8000\nMIXPANEL_API_KEY=\n'


class PreviewConfigurationTest(unittest.TestCase):
    def test_no_credentials_uses_the_example(self):
        contents, configured = prepare(EXAMPLE, {})
        self.assertEqual(contents, EXAMPLE)
        self.assertFalse(any(configured.values()))

    def test_partial_public_configuration_is_retained_without_signing(self):
        contents, configured = prepare(EXAMPLE, {
            'FLIXQUEST_ENV': 'TMDB_API_KEY=abc123\nFLIXQUEST_API_URL=https://provider.test\n'
                             'LARAVEL_API_URL=https://backend.test\n'
                             'SOME_SECRET=do-not-copy\n',
        })
        self.assertEqual(dotenv_values(contents)['TMDB_API_KEY'], 'abc123')
        self.assertEqual(dotenv_values(contents)['FLIXQUEST_API_URL'], 'https://provider.test')
        self.assertEqual(dotenv_values(contents)['LARAVEL_API_URL'], 'https://backend.test')
        self.assertNotIn('do-not-copy', contents)
        self.assertTrue(all(configured.values()))

    def test_individual_preview_values_override_multiline_configuration(self):
        contents, _ = prepare(EXAMPLE, {
            'FLIXQUEST_ENV': 'TMDB_API_KEY=old\nFLIXQUEST_API_URL=https://old.test\n',
            'PREVIEW_TMDB_API_KEY': 'new',
            'PREVIEW_PROVIDER_URL': 'https://new.test/api/v2',
        })
        self.assertEqual(dotenv_values(contents)['TMDB_API_KEY'], 'new')
        self.assertEqual(dotenv_values(contents)['FLIXQUEST_API_URL'], 'https://new.test/api/v2')

    def test_rejects_tokens_credential_urls_interpolation_and_injection(self):
        for overrides in (
            {'PREVIEW_TMDB_API_KEY': 'Bearer token'},
            {'PREVIEW_TMDB_API_KEY': 'eyJ.abc.def'},
            {'PREVIEW_PROVIDER_URL': 'https://user:secret@provider.test'},
            {'PREVIEW_PROVIDER_URL': 'https://provider.test/?key=secret'},
            {'PREVIEW_PROVIDER_URL': 'https://${PROVIDER}'},
            {'PREVIEW_PROVIDER_URL': 'https://provider.test\nSECRET=bad'},
        ):
            with self.subTest(overrides=overrides), self.assertRaises(ValueError):
                prepare(EXAMPLE, overrides)

    def test_no_value_is_printed_and_output_is_private(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.env.example').write_text(EXAMPLE)
            result = subprocess.run(
                [sys.executable, str(SCRIPT)], cwd=root, capture_output=True,
                text=True, env={**os.environ, 'FLIXQUEST_ENV': '',
                                'PREVIEW_TMDB_API_KEY': 'private-test-key'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('private-test-key', result.stdout + result.stderr)
            self.assertIn('Preview TMDB client key: configured', result.stdout)
            self.assertEqual((root / '.env').stat().st_mode & 0o777, 0o600)
            self.assertIn('private-test-key', (root / '.env').read_text())


if __name__ == '__main__':
    unittest.main()
