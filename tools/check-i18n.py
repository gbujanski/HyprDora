"""Checks the translations: every language has English's keys, and each file lists them alphabetically.

Usage: check-i18n.py FILE... (English is shell/i18n/en.json); exits 1 on a problem.
"""

import json
import sys
from pathlib import Path


def main(files: list[str]) -> int:
    """Prints each problem found and returns the exit code."""
    english = set(json.loads(Path("shell/i18n/en.json").read_text()))
    bad = False
    for name in files:
        keys = list(json.loads(Path(name).read_text()))
        if keys != sorted(keys):
            print(f"{name}: keys not in alphabetical order")
            bad = True
        missing, extra = sorted(english - set(keys)), sorted(set(keys) - english)
        if missing or extra:
            print(f"{name}: missing {missing}, extra {extra}")
            bad = True
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
