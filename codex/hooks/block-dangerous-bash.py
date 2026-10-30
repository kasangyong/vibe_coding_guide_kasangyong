#!/usr/bin/env python3
# PreToolUse(Bash) guardrail: block dangerous command patterns with exit code 2.
# Windows-robust: invoked via `python`, no bash dependency.
# Fail-open on unparseable input (matches original .sh behavior).
import sys, json, re

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # can't parse -> allow

cmd = (data.get("tool_input") or {}).get("command", "") or ""

deny_patterns = [
    r'rm\s+-rf\s+/',
    r'rm\s+-rf\s+~',
    r'rm\s+-rf\s+\*',
    r':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:',   # fork bomb
    r'\bmkfs\b',
    r'dd\s+if=.*\s+of=/dev/',
    r'\bsudo\s+rm\b',
    r'chmod\s+-R\s+777\s+/',
    r'>\s*/dev/sd',
]

for p in deny_patterns:
    if re.search(p, cmd):
        print(f"DENIED: dangerous pattern matched: {p}", file=sys.stderr)
        sys.exit(2)

sys.exit(0)
