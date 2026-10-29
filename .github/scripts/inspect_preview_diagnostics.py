#!/usr/bin/env python3
"""One-off inspection of a clean emulator's startup failure diagnostics."""
import base64
from collections import Counter
from io import BytesIO
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
from PIL import Image

root = Path(sys.argv[1])
ui = root / 'window.xml'
if ui.exists():
    try:
        nodes = list(ET.parse(ui).getroot().iter())
        packages = Counter(node.get('package', '') for node in nodes)
        for package, count in packages.items():
            print(f'::notice::UI package {package or "(none)"}: {count} nodes')
        for node in nodes[:25]:
            text = node.get('text', '').strip()
            desc = node.get('content-desc', '').strip()
            label = text or desc
            if label:
                # Only print labels from known Android system UI, never the
                # application's potentially credential-bearing field values.
                package = node.get('package', '')
                if package.startswith(('com.android.', 'android')):
                    label = re.sub(r'https?://\S+|[A-Za-z0-9_-]{32,}', '[redacted]', label)
                    print(f'::notice::System UI label: {label[:160]}')
                else:
                    print(f'::notice::App UI label length: {len(label)}')
    except ET.ParseError:
        print('::warning::UI hierarchy could not be parsed.')
else:
    print('::warning::No UI hierarchy was captured.')
errors = root / 'errors.log'
if errors.exists():
    lines = []
    for line in errors.read_text(errors='replace').splitlines():
        if re.search(r'exception|fatal|error|firebase|failed', line, re.I):
            line = re.sub(r'https?://\S+|[A-Za-z0-9_-]{32,}', '[redacted]', line)
            lines.append(line[:300])
    for line in lines[-12:]:
        print('::notice::' + line.replace('%', '%25'))
    print(f'::notice::Filtered error-log lines: {len(lines)}')
image = root / 'screen.png'
if image.exists():
    im = Image.open(image).convert('RGB')
    im.thumbnail((400, 800))
    encoded = BytesIO()
    im.save(encoded, format='JPEG', quality=55, optimize=True)
    text = base64.b64encode(encoded.getvalue()).decode('ascii')
    for i in range(0, len(text), 3000):
        print(f'::notice title=Startup image {i // 3000:03}::{text[i:i+3000]}')
    print(f'::notice::Startup image chunks: {(len(text) + 2999) // 3000}')
PY
