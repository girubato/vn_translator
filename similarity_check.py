#!/usr/bin/env python3
"""
Simple similarity check for fuzzy text matching.
Returns exit code 0 if texts are similar (above threshold), 1 if different.
"""

import sys
from difflib import SequenceMatcher

def similarity(a: str, b: str) -> float:
    """Return similarity ratio between two strings (0.0 to 1.0)"""
    return SequenceMatcher(None, a, b).ratio()

def main():
    if len(sys.argv) < 3:
        print("Usage: similarity_check.py <text1> <text2> [threshold]", file=sys.stderr)
        sys.exit(2)

    text1 = sys.argv[1]
    text2 = sys.argv[2]
    threshold = float(sys.argv[3]) if len(sys.argv) > 3 else 0.85

    ratio = similarity(text1, text2)

    # Exit 0 if similar (should skip), exit 1 if different (should translate)
    if ratio >= threshold:
        sys.exit(0)  # Similar enough, skip
    else:
        sys.exit(1)  # Different enough, process

if __name__ == "__main__":
    main()
