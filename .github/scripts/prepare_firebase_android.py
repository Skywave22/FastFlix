#!/usr/bin/env python3
"""Prepare variant-scoped Firebase options without pretending preview is registered.

The debug-only placeholder cannot service Firebase. Release builds require a
real google-services.json for the original application ID and a project the builder is authorized to use.
"""
import json
import os
from pathlib import Path
import re
import sys

PACKAGE = "dev.beamlak.flixquest_v2"


def validate(contents: str) -> None:
    try:
        doc = json.loads(contents)
        project = doc["project_info"]
        number = str(project["project_number"])
        project_id = str(project["project_id"])
        clients = doc["client"]
        matches = [c for c in clients if c["client_info"]["android_client_info"]["package_name"] == PACKAGE]
        if len(matches) != 1 or not number.isdigit() or int(number) == 0:
            raise ValueError()
        if not re.fullmatch(r"[a-z][a-z0-9-]{4,61}[a-z0-9]", project_id) or "preview" in project_id.lower():
            raise ValueError()
        client = matches[0]
        app_id = str(client["client_info"]["mobilesdk_app_id"])
        if not re.fullmatch(rf"1:{re.escape(number)}:android:[0-9a-fA-F]{{16,}}", app_id) or set(app_id.split(":")[-1]) == {"0"}:
            raise ValueError()
        keys = client.get("api_key", [])
        if not any(re.fullmatch(r"AIza[\w-]{30,}", str(key.get("current_key", ""))) for key in keys):
            raise ValueError()
    except (ValueError, TypeError, KeyError, IndexError, json.JSONDecodeError):
        raise ValueError(
            f"FIREBASE_ANDROID_CONFIG must be a genuine Google services JSON for {PACKAGE}; "
            "register that Android app in Firebase and supply its downloaded file."
        ) from None


def preview_config() -> dict:
    # Deliberately fake, isolated from any real project credentials. Only the
    # prod/debug source set can see it; it is never accepted for production.
    return {
        "project_info": {"project_number": "0", "project_id": "flixquest-preview-invalid", "storage_bucket": "flixquest-preview.invalid"},
        "client": [{
            "client_info": {"mobilesdk_app_id": "1:0:android:0000000000000000", "android_client_info": {"package_name": PACKAGE}},
            "oauth_client": [],
            "api_key": [{"current_key": "preview-only-not-a-real-firebase-key"}],
            "services": {"appinvite_service": {"other_platform_oauth_client": []}},
        }],
        "configuration_version": "1",
    }


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in ("preview", "release"):
        raise SystemExit("Usage: prepare_firebase_android.py preview|release")
    mode = sys.argv[1]
    if mode == "preview":
        contents = json.dumps(preview_config(), indent=2) + "\n"
        target = Path("android/app/src/prod/debug/google-services.json")
        print("::warning::Preview uses deliberately invalid Firebase options; Firebase services will not work.")
    else:
        contents = os.environ.get("FIREBASE_ANDROID_CONFIG", "")
        try:
            validate(contents)
        except ValueError as error:
            print(f"::error::{error}", file=sys.stderr)
            raise SystemExit(1) from None
        target = Path("android/app/src/prod/release/google-services.json")
        print(f"Firebase package configuration validated for {PACKAGE}.")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(contents, encoding="utf-8")
    if mode == "release":
        # CI also runs prod/debug Android unit tests after the release build.
        debug = Path("android/app/src/prod/debug/google-services.json")
        debug.parent.mkdir(parents=True, exist_ok=True)
        debug.write_text(contents, encoding="utf-8")


if __name__ == "__main__":
    main()
