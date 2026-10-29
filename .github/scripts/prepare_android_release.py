#!/usr/bin/env python3
"""Prepare runner-only signing files and the public-client .env for an APK build."""

import base64
import binascii
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit


def fail(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)
    raise SystemExit(1)


def required_secret(name: str) -> str:
    value = os.environ.get(name, "")
    if not value.strip():
        fail(f"Missing required GitHub Actions secret: {name}")
    return value


def dotenv_values(contents: str) -> dict[str, str]:
    """Read the simple KEY=value entries used by the documented release .env."""
    values = {}
    for line in contents.splitlines():
        match = re.match(
            r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", line
        )
        if match is None:
            continue
        key, value = match.groups()
        if value and value[0] in "\"'":
            end = value.find(value[0], 1)
            if end == -1:
                fail(f"FLIXQUEST_ENV has an unclosed quote for {key}")
            value = value[1:end]
        else:
            value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
        # flutter_dotenv keeps the first definition of a duplicate key.
        values.setdefault(key, value)
    return values


def check_public_url(name: str, value: str) -> None:
    try:
        parsed = urlsplit(value)
        hostname = parsed.hostname
        # Accessing port also checks malformed ports and IPv6 literals.
        _ = parsed.port
    except ValueError:
        fail(f"{name} in FLIXQUEST_ENV must be a valid public-client URL")
    if (
        parsed.scheme not in ("http", "https")
        or not hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or hostname.lower() in {"localhost", "127.0.0.1", "0.0.0.0", "::1", "10.0.2.2"}
    ):
        fail(f"{name} in FLIXQUEST_ENV must be a non-local HTTP(S) base URL")


def property_value(value: str) -> str:
    """Escape a value for java.util.Properties.load, including Unicode."""
    result = []
    escapes = {"\\": "\\\\", "\n": "\\n", "\r": "\\r", "\t": "\\t", "\f": "\\f"}
    for char in value:
        if char in escapes:
            result.append(escapes[char])
        elif char in " =:#!":
            result.append("\\" + char)
        elif not 0x20 <= ord(char) <= 0x7E:
            encoded = char.encode("utf-16-be")
            result.extend(
                f"\\u{int.from_bytes(encoded[i:i + 2], 'big'):04x}"
                for i in range(0, len(encoded), 2)
            )
        else:
            result.append(char)
    return "".join(result)


def private_write(path: Path, data: bytes) -> None:
    # The parent directories already exist; restrict permissions from creation.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as output:
        os.fchmod(output.fileno(), 0o600)
        output.write(data)


def main() -> None:
    client_env = required_secret("FLIXQUEST_ENV")
    signing = {
        "storePassword": required_secret("ANDROID_STORE_PASSWORD"),
        "keyPassword": required_secret("ANDROID_KEY_PASSWORD"),
        "keyAlias": required_secret("ANDROID_KEY_ALIAS"),
    }
    encoded_keystore = required_secret("ANDROID_KEYSTORE_BASE64")
    values = dotenv_values(client_env)
    for key in ("TMDB_API_KEY", "FLIXQUEST_API_URL", "LARAVEL_API_URL"):
        if not values.get(key, "").strip():
            fail(f"FLIXQUEST_ENV must define a non-empty {key}")
        if "$" in values[key]:
            fail(
                f"{key} in FLIXQUEST_ENV must use a literal value, not variable interpolation"
            )
    if "MIXPANEL_API_KEY" not in values:
        fail("FLIXQUEST_ENV must include MIXPANEL_API_KEY (it may be empty)")
    for key in ("FLIXQUEST_API_URL", "LARAVEL_API_URL"):
        check_public_url(key, values[key])

    try:
        keystore = base64.b64decode(re.sub(r"\s+", "", encoded_keystore), validate=True)
    except (ValueError, binascii.Error):
        fail("ANDROID_KEYSTORE_BASE64 is not valid base64")
    if not keystore:
        fail("ANDROID_KEYSTORE_BASE64 decoded to an empty file")

    runner_temp = os.environ.get("RUNNER_TEMP")
    if not runner_temp:
        fail("RUNNER_TEMP is required to store the signing key outside the project")
    key_path = Path(runner_temp).resolve() / "flixquest-release-keystore.jks"
    signing["storeFile"] = str(key_path)
    properties = "".join(
        f"{key}={property_value(value)}\n" for key, value in signing.items()
    )
    private_write(key_path, keystore)
    private_write(Path("android/key.properties"), properties.encode("ascii"))
    private_write(Path(".env"), (client_env.rstrip("\r\n") + "\n").encode("utf-8"))
    print("Prepared release signing and public-client configuration.")


if __name__ == "__main__":
    main()
