#!/usr/bin/env python3
"""Prepare a preview using *only* explicitly supplied public-client values.

Anything in .env is shipped in the APK, including a TMDB v3 key. Never put
passwords, access tokens, signing keys, or server secrets in these inputs.
"""
import os
from pathlib import Path
import re
from urllib.parse import urlsplit

from prepare_android_release import dotenv_values, private_write


CLIENT_FIELDS = ('TMDB_API_KEY', 'FLIXQUEST_API_URL', 'LARAVEL_API_URL')
OVERRIDES = {
    'TMDB_API_KEY': 'PREVIEW_TMDB_API_KEY',
    'FLIXQUEST_API_URL': 'PREVIEW_PROVIDER_URL',
    'LARAVEL_API_URL': 'PREVIEW_BACKEND_URL',
}


def validate_client_values(values: dict[str, str]) -> None:
    key = values.get('TMDB_API_KEY', '')
    if key and not re.fullmatch(r'[A-Za-z0-9_-]{1,256}', key):
        raise ValueError('TMDB_API_KEY must be a public v3 API key, not an access token or URL')
    for name in ('FLIXQUEST_API_URL', 'LARAVEL_API_URL'):
        value = values.get(name, '')
        if not value:
            continue
        try:
            uri = urlsplit(value)
            # A port is optional, but inspecting it rejects malformed ports.
            valid = (uri.scheme in ('http', 'https') and bool(uri.hostname) and
                     uri.username is None and uri.password is None and
                     not uri.query and not uri.fragment and
                     not any(char.isspace() for char in value) and
                     '$' not in value)
            _ = uri.port
        except ValueError:
            valid = False
        if not valid:
            raise ValueError(f'{name} must be a credential-free HTTP(S) base URL')


def prepare(example: str, environment: dict[str, str]) -> tuple[str, dict[str, bool]]:
    bundled = dotenv_values(environment.get('FLIXQUEST_ENV', ''))
    values = {}
    for name in CLIENT_FIELDS:
        explicit = environment.get(OVERRIDES[name], '').strip()
        value = explicit or bundled.get(name, '').strip()
        if value:
            values[name] = value
    validate_client_values(values)

    output = []
    seen = set()
    for line in example.splitlines():
        match = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=', line)
        name = match.group(1) if match else ''
        if name in values:
            if name in seen:
                continue
            line = f'{name}={values[name]}'
            seen.add(name)
        output.append(line)
    for name in CLIENT_FIELDS:
        if name in values and name not in seen:
            output.append(f'{name}={values[name]}')
    return '\n'.join(output) + '\n', {name: name in values for name in CLIENT_FIELDS}


def main() -> None:
    try:
        contents, configured = prepare(Path('.env.example').read_text(), dict(os.environ))
    except ValueError as error:
        raise SystemExit(f'::error::{error}') from None
    private_write(Path('.env'), contents.encode('utf-8'))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with Path(summary).open('a', encoding='utf-8') as handle:
            handle.write('### Debug preview configuration\n')
            for label, name in (('TMDB client key', 'TMDB_API_KEY'),
                                ('Provider API URL', 'FLIXQUEST_API_URL'),
                                ('Backend URL', 'LARAVEL_API_URL')):
                state = 'configured' if configured[name] else 'not configured'
                handle.write(f'- {label}: {state}\n')
            handle.write('These public-client values are bundled in the APK; '
                         'anyone with the artifact can inspect them.\n')
    for label, name in (('TMDB client key', 'TMDB_API_KEY'),
                        ('Provider API URL', 'FLIXQUEST_API_URL'),
                        ('Backend URL', 'LARAVEL_API_URL')):
        state = 'configured' if configured[name] else 'not configured'
        print(f'::notice::Preview {label}: {state} (value not shown).')
    print('Prepared preview public-client configuration without printing values.')


if __name__ == '__main__':
    main()
