#!/usr/bin/env python3
"""Summarize preview build failures as GitHub annotations."""

import re
import sys
from pathlib import Path


ANSI = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")
ERROR = re.compile(
    r"(?:^|\s)(?:error:|failure:|what went wrong:|execution failed|e: |fatal error:)",
    re.IGNORECASE,
)


def annotations(log: str) -> list[str]:
    lines = ANSI.sub("", log).splitlines()
    indices = [index for index, line in enumerate(lines) if ERROR.search(line)]
    excerpts = ["\n".join(lines[i : i + 4])[:3000] for i in indices[-15:]]
    if not excerpts:
        excerpts = ["\n".join(lines[-30:])[-3000:] or "No build output was captured."]
    return [
        excerpt.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        for excerpt in excerpts
    ]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: report_android_failure.py BUILD_LOG")
    for excerpt in annotations(Path(sys.argv[1]).read_text(errors="replace")):
        print(f"::error title=Android preview build failed::{excerpt}")


if __name__ == "__main__":
    main()
