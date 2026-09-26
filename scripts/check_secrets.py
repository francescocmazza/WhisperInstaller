"""Very small defensive secret/personal-data scanner for CI.

This is not a substitute for GitHub secret scanning or gitleaks, but it catches
the common accidental credentials that should never enter this public repo.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {".git", "__pycache__", "Output", "dist", "build", "runtime"}
SKIP_FILES = {"check_secrets.py"}

PATTERNS = {
    "GitHub classic token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"),
    "GitHub fine-grained token": re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    "OpenAI-style key": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
    "AWS access key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "Windows user profile path": re.compile(r"(?i)\bC:\\Users\\(?!Public\b|Default\b)[^\\\s]+\\"),
}

bad = []

for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    if path.name in SKIP_FILES:
        continue
    if any(part in SKIP_DIRS for part in path.parts):
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    for label, pattern in PATTERNS.items():
        if pattern.search(text):
            bad.append((path.relative_to(ROOT), label))

if bad:
    for path, label in bad:
        print(f"FAIL: {path}: possible {label}")
    raise SystemExit(1)

print("Secret/personal-path scan: OK")
