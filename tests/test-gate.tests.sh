#!/usr/bin/env bash
# test-gate.tests.sh - 21-case regression suite for skills/test-gate/scripts/test-gate.sh.
# Cases encode the adversarial-review findings of 2026-07-15/18 (see git history of
# the skill): classification, signature re-arm after commit, alternation memory,
# deletion-aware diffing, no-HEAD repos, hostile filenames, fail-open state, prune.
# Fixtures live in a temp dir only; the repo is never touched. Exit 0 = all pass.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(dirname "$HERE")/skills/test-gate/scripts/test-gate.sh"
[ -f "$HOOK" ] || { echo "[FAIL] hook not found: $HOOK"; exit 1; }
WORK=$(mktemp -d) || exit 1
trap 'cd /; rm -rf "$WORK"' EXIT
unset CLAUDE_PROJECT_DIR

P=0; F=0
run(){ echo '{}' | bash "$HOOK"; }
mkrepo(){ rm -rf "$1" && mkdir -p "$1" && cd "$1" && git init -q . \
          && git config user.email t@t.t && git config user.name t \
          && git config commit.gpgsign false; }
ck(){ if [ "$1" = ok ]; then P=$((P+1)); echo "[PASS] $2"; \
      else F=$((F+1)); echo "[FAIL] $2${3:+ - got: $3}"; fi; }

# --- main flow: block once, signature memory, re-arm on commit, alternation ---
mkrepo "$WORK/f1"; echo base>base.py; git add -A; git commit -qm i
echo x>a.py
o=$(run); case "$o" in '{"decision":"block"'*a.py*) ck ok "T1 src without tests blocks";; *) ck no "T1 src without tests blocks" "${o:-SILENT}";; esac
o=$(run); [ -z "$o" ] && ck ok "T2 same state stays silent" || ck no "T2 same state stays silent" "$o"
git add -A; git commit -qm a; echo y>>a.py
o=$(run); case "$o" in *'"decision":"block"'*) ck ok "T3 new commit re-arms the gate";; *) ck no "T3 new commit re-arms the gate" "${o:-SILENT}";; esac
git checkout -q -- a.py; echo z>b.py
o=$(run); case "$o" in *block*b.py*) ck ok "T4 different file set blocks";; *) ck no "T4 different file set blocks" "${o:-SILENT}";; esac
rm b.py; echo y>>a.py
o=$(run); [ -z "$o" ] && ck ok "T5 alternating sets do not re-nag" || ck no "T5 alternating sets do not re-nag" "$o"
echo t>test_a.py
o=$(run); [ -z "$o" ] && ck ok "T6 accompanying test file satisfies" || ck no "T6 accompanying test file satisfies" "$o"

# --- fresh repo without HEAD: staged work must still be gated ---
mkrepo "$WORK/f2"; echo x>app.py; git add app.py
o=$(run); case "$o" in *'"decision":"block"'*app.py*) ck ok "T7 staged file in no-HEAD repo blocks";; *) ck no "T7 staged file in no-HEAD repo blocks" "${o:-SILENT}";; esac

# --- deletions: removing tests never satisfies; deletion-only never blocks ---
mkrepo "$WORK/f3"; echo x>app.py; echo t>test_app.py; git add -A; git commit -qm i
rm test_app.py; echo y>>app.py
o=$(run); case "$o" in *'"decision":"block"'*) ck ok "T8 deleted test does not satisfy";; *) ck no "T8 deleted test does not satisfy" "${o:-SILENT}";; esac
git checkout -q -- .; rm app.py
o=$(run); [ -z "$o" ] && ck ok "T9 deletion-only change silent" || ck no "T9 deletion-only change silent" "$o"

# --- hostile / tricky names, rust exclusion, docs-only, non-repo ---
mkrepo "$WORK/f4"; echo base>base.py; git add -A; git commit -qm i
echo x>"módulo.py"; echo y>"spa ce.py"; echo z>contest.py; echo w>latest.js
o=$(run)
case "$o" in *'"decision":"block"'*dulo.py*"spa ce.py"*) ck ok "T10 C-quoted/unicode names classified";; *) ck no "T10 C-quoted/unicode names classified" "$o";; esac
case "$o" in *módulo*) ck no "T11 non-ASCII never reaches JSON raw" "$o";; *) ck ok "T11 non-ASCII never reaches JSON raw";; esac
case "$o" in *contest.py*latest.js*) ck ok "T12 contest.py/latest.js are src not tests";; *) ck no "T12 contest.py/latest.js are src not tests" "$o";; esac
rm "módulo.py" "spa ce.py" contest.py latest.js .git/claude-test-gate-seen
echo r>main.rs
o=$(run); [ -z "$o" ] && ck ok "T13 rust excluded by default (inline tests)" || ck no "T13 rust excluded by default (inline tests)" "$o"
rm main.rs; echo d>README.md
o=$(run); [ -z "$o" ] && ck ok "T14 docs-only change silent" || ck no "T14 docs-only change silent" "$o"
cd "$WORK"
o=$(run); [ -z "$o" ] && ck ok "T15 non-repo dir silent" || ck no "T15 non-repo dir silent" "$o"

# --- fail-open when state cannot persist; prune above 100 entries ---
mkrepo "$WORK/f5"; echo base>base.py; git add -A; git commit -qm i
mkdir .git/claude-test-gate-seen   # occupy the state path: append must fail
echo x>a.py
o=$(run); [ -z "$o" ] && ck ok "T16 unwritable state fails open (no block)" || ck no "T16 unwritable state fails open (no block)" "$o"
o=$(run); [ -z "$o" ] && ck ok "T17 fail-open does not loop" || ck no "T17 fail-open does not loop" "$o"
rmdir .git/claude-test-gate-seen
for i in $(seq 1 150); do echo "sig$i"; done > .git/claude-test-gate-seen
o=$(run); case "$o" in *'"decision":"block"'*) ck ok "T18 oversized state still blocks";; *) ck no "T18 oversized state still blocks" "${o:-SILENT}";; esac
lines=$(wc -l < .git/claude-test-gate-seen | tr -d ' ')
[ "$lines" -eq 100 ] && ck ok "T19 state pruned to 100 lines" || ck no "T19 state pruned to 100 lines" "$lines"
tail -1 .git/claude-test-gate-seen | grep -Eq '^[0-9a-f]{40}$' && ck ok "T20 newest signature survives prune" || ck no "T20 newest signature survives prune"
if ls .git/claude-test-gate-seen.tmp.* >/dev/null 2>&1; then ck no "T21 no tmp litter after prune"; else ck ok "T21 no tmp litter after prune"; fi

echo "test-gate suite: $P passed, $F failed"
[ "$F" -eq 0 ] || exit 1
exit 0
