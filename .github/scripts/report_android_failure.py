#!/usr/bin/env python3
"""Summarize preview build failures as GitHub annotations."""

import re
import sys
from pathlib import Path


ANSI = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")
ERROR = re.compile(
    r"(?:^|\s)(?:error:|failure:|what went wrong:|execution failed|e: |fatal error:|\[E\]|Expected:|Actual:|EXCEPTION CAUGHT|TestFailure)|❌",
    re.IGNORECASE,
)


def annotations(log: str) -> list[str]:
    lines = ANSI.sub("", log).splitlines()
    indices = [index for index, line in enumerate(lines) if ERROR.search(line)]
    excerpts = []
    for i in indices[:15]:
        # Flutter's expanded reporter prints the exception before the [E]
        # marker; include context so the failed test and assertion survive
        # GitHub's annotation-size limit.
        if "[E]" in lines[i] or "❌" in lines[i]:
            excerpt = "\n".join(lines[max(0, i - 14) : i + 6])
        else:
            excerpt = "\n".join(lines[i : i + 8])
        excerpts.append(excerpt[:3000])
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
        print(f"::error title=Android validation failed::{excerpt}")


if __name__ == "__main__":
    main()
