#!/usr/bin/env python3
"""Select a signed release or a clearly labeled, secret-free preview build."""

import os
from pathlib import Path


REQUIRED_SECRETS = (
    "FLIXQUEST_ENV",
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_STORE_PASSWORD",
    "ANDROID_KEY_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "FIREBASE_ANDROID_CONFIG",
)


def select_mode(
    event_name: str, ref_type: str, release_tag: str, values: dict[str, str]
) -> str:
    """Publishing must always require release configuration, never a preview."""
    publishing = (event_name == "push" and ref_type == "tag") or (
        event_name == "workflow_dispatch" and release_tag != ""
    )
    if publishing or all(values.get(name, "").strip() for name in REQUIRED_SECRETS):
        return "release"
    return "preview"


def main() -> None:
    mode = select_mode(
        os.environ.get("GITHUB_EVENT_NAME", ""),
        os.environ.get("GITHUB_REF_TYPE", ""),
        os.environ.get("INPUT_RELEASE_TAG", ""),
        os.environ,
    )
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        raise SystemExit("GITHUB_OUTPUT is required")
    with Path(output).open("a", encoding="utf-8") as handle:
        handle.write(f"mode={mode}\n")
    if mode == "preview":
        print(
            "::warning::Building a debug preview with example configuration. "
            "It is not a production release and online features may not work."
        )
    else:
        print("Building with release configuration and signing.")


if __name__ == "__main__":
    main()
