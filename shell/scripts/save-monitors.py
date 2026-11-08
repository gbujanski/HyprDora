#!/usr/bin/env python3
"""Save monitor rules to the HyprDora block in monitors.conf.

Usage: save-monitors.py PATH, with a JSON list of rules on stdin.
The rest of the file, including the fallback rule, is left unchanged. The
original file is copied once to .orig, and the state before each save to .bak.
The write is atomic.
"""

import json
import os
import shutil
import sys
import tempfile

BEGIN = "# >>> HyprDora: managed by the action center"
END = "# <<< HyprDora"


def without_block(lines):
    """Return the lines outside the managed block."""
    result = []
    inside = False
    for line in lines:
        stripped = line.strip()
        if stripped == BEGIN:
            inside = True
        elif stripped == END:
            inside = False
        elif not inside:
            result.append(line)
    return result


def main():
    """Merge the rules into the file and return an exit code."""
    path = sys.argv[1]
    rules = json.load(sys.stdin)
    if not isinstance(rules, list) or not rules or not all(isinstance(r, str) and "\n" not in r for r in rules):
        print("invalid rules", file=sys.stderr)
        return 2

    original = ""
    if os.path.exists(path):
        with open(path, encoding="utf-8") as source:
            original = source.read()
        if not os.path.exists(path + ".orig"):
            shutil.copy2(path, path + ".orig")
        shutil.copy2(path, path + ".bak")

    kept = without_block(original.splitlines())
    while kept and not kept[-1].strip():
        kept.pop()
    block = [BEGIN, *(f"monitor={rule}" for rule in rules), END]
    content = "\n".join([*kept, *([""] if kept else []), *block]) + "\n"

    directory = os.path.dirname(os.path.abspath(path))
    descriptor, temporary = tempfile.mkstemp(dir=directory, prefix=".monitors-", suffix=".tmp")
    with os.fdopen(descriptor, "w", encoding="utf-8") as target:
        target.write(content)
    os.replace(temporary, path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
