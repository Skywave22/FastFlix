#!/usr/bin/env python3
"""Inspect public URL defaults in the upstream's publicly distributed APK.

Do not print, copy, test, persist separately, or use any upstream client keys.
This reports only whether a key exists and performs an unauthenticated request
against an explicitly bundled, credential-free service URL.
"""
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile


def note(message):
    print(f'::notice::{message}')


with zipfile.ZipFile(sys.argv[1]) as archive:
    matches = [n for n in archive.namelist() if n.endswith('/flutter_assets/.env')]
    if len(matches) != 1:
        note('Upstream APK does not expose a single bundled .env asset.')
        raise SystemExit(0)
    content = archive.read(matches[0]).decode('utf-8-sig')

values = {}
for line in content.splitlines():
    text = line.strip()
    if not text or text.startswith('#') or '=' not in text:
        continue
    name, value = text.split('=', 1)
    name, value = name.strip(), value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        value = value[1:-1]
    values.setdefault(name, value)

note('Upstream APK includes a TMDB client key: ' +
     ('yes' if values.get('TMDB_API_KEY') else 'no'))
for name in ('FLIXQUEST_API_URL', 'LARAVEL_API_URL'):
    raw = values.get(name, '')
    try:
        uri = urllib.parse.urlsplit(raw)
        safe = (uri.scheme in ('http', 'https') and uri.hostname and
                not uri.username and not uri.password and not uri.query and
                not uri.fragment)
        host = uri.hostname if safe else None
    except ValueError:
        safe, host = False, None
    if not safe:
        note(f'Upstream {name}: absent or not a credential-free URL.')
        continue
    note(f'Upstream {name} host: {host}')
    if name != 'FLIXQUEST_API_URL':
        continue
    root = raw.rstrip('/')
    if not root.endswith('/api/v2'):
        root += '/api/v2'
    request = urllib.request.Request(root + '/providers', headers={'Accept': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            result = json.load(response)
            providers = result.get('providers', []) if isinstance(result, dict) else []
            note(f'Upstream provider catalog returned HTTP {response.status}; '
                 f'provider entries: {len(providers) if isinstance(providers, list) else 0}.')
    except urllib.error.HTTPError as error:
        note(f'Upstream provider catalog returned HTTP {error.code}.')
    except Exception:
        note('Upstream provider catalog was not reachable from the CI runner.')
