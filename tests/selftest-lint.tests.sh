#!/usr/bin/env bash
# selftest-lint.tests.sh - mutation self-test for lint-skills.ps1.
# A checker that cannot fail is decoration: this builds a synthetic skills tree
# containing known defects and asserts the linter reports each one and exits 1,
# and that a defect-free tree (warnings allowed) exits 0.
# Fixtures live in a temp dir only. Requires powershell + cygpath (Git Bash).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LINT="$(dirname "$HERE")/skills/claude-config-diagnostics/scripts/lint-skills.ps1"
[ -f "$LINT" ] || { echo "[FAIL] linter not found: $LINT"; exit 1; }
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
S="$WORK/skills"; mkdir -p "$S"

P=0; F=0
ck(){ if [ "$1" = ok ]; then P=$((P+1)); echo "[PASS] $2"; \
      else F=$((F+1)); echo "[FAIL] $2"; fi; }
run_lint(){ powershell -ExecutionPolicy Bypass -File "$LINT" -SkillsDir "$(cygpath -w "$S")" 2>&1; }

mkskill(){ mkdir -p "$S/$1"; printf '%s\n' "$2" > "$S/$1/SKILL.md"; }

# --- Tree A: clean skill + two WARN-only skills -> exit 0, WARNs reported ---
mkskill good-skill '---
name: good-skill
description: Does one thing well - alpha, beta. Use when self-testing the linter.
---

# Good Skill

References its sibling `warn-usewhen` legitimately.'
mkskill warn-usewhen '---
name: warn-usewhen
description: A description with no trigger clause at all.
---

# Warn Usewhen'
mkskill warn-sibling '---
name: warn-sibling
description: Refers to a ghost - alpha, beta. Use when self-testing the linter.
---

# Warn Sibling

See `no-such-skill` for the thing that does not exist.'

out=$(run_lint); rc=$?
[ "$rc" -eq 0 ] && ck ok "clean tree (WARNs only) exits 0" || { ck no "clean tree (WARNs only) exits 0"; echo "$out"; }
echo "$out" | grep -q "\[PASS\] good-skill" && ck ok "clean skill reported PASS" || ck no "clean skill reported PASS"
echo "$out" | grep -q "Use when" && ck ok "missing 'Use when' clause WARNed" || ck no "missing 'Use when' clause WARNed"
echo "$out" | grep -q "no-such-skill" && ck ok "unresolvable sibling reference WARNed" || ck no "unresolvable sibling reference WARNed"

# --- Tree B: add one skill per defect class -> exit 1, each defect named ---
mkskill bad-name '---
name: something-else
description: Name mismatch fixture - alpha, beta. Use when self-testing the linter.
---

# Bad Name'
longdesc=$(printf 'a%.0s' $(seq 1 201))
mkskill bad-desc "---
name: bad-desc
description: $longdesc
---

# Bad Desc"
mkskill bad-open '---
name: bad-open
description: Frontmatter never closes - alpha. Use when self-testing the linter.

# Bad Open'
mkskill bad-ref '---
name: bad-ref
description: References a missing file - alpha. Use when self-testing the linter.
---

# Bad Ref

Run scripts/gone.sh to reproduce.'

out=$(run_lint); rc=$?
[ "$rc" -eq 1 ] && ck ok "defective tree exits 1" || { ck no "defective tree exits 1"; echo "$out"; }
echo "$out" | grep -q "does not equal folder name" && ck ok "name/folder mismatch FAILed" || ck no "name/folder mismatch FAILed"
echo "$out" | grep -q "201 chars" && ck ok "201-char description FAILed" || ck no "201-char description FAILed"
echo "$out" | grep -q "never closed" && ck ok "unclosed frontmatter FAILed" || ck no "unclosed frontmatter FAILed"
echo "$out" | grep -q "scripts/gone.sh" && ck ok "missing referenced script FAILed" || ck no "missing referenced script FAILed"

echo "selftest-lint suite: $P passed, $F failed"
[ "$F" -eq 0 ] || exit 1
exit 0
