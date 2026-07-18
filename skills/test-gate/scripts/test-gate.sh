#!/usr/bin/env bash
# test-gate: per-repo Stop hook. When uncommitted changes include source files
# (SRC_RE) and no test files (TEST_RE_*), block the stop once per signature
# with a reason routing the session to the test-gate skill (test-or-justify).
# Exit 0 silently in every other case.
#
# Mechanics (SKILL.md defers to this header):
# - Change set: staged+unstaged vs HEAD (vs the empty tree in a repo with no
#   commits yet), deletions excluded (--diff-filter=d), plus untracked
#   non-ignored files. NUL-separated output so C-quoted paths (non-ASCII,
#   spaces) cannot defeat the $-anchored regexes.
# - Signature: hash of HEAD + the untested source list. Seen signatures append
#   to .git/claude-test-gate-seen (per worktree, never committed, pruned to
#   the last 100): one nudge per state; a new commit or a different file set
#   re-arms the gate; alternating file sets cannot re-nag under one HEAD.
#   If the signature cannot be persisted (read-only .git), the hook FAILS
#   OPEN — it allows the stop rather than nag unboundedly.
# - Mode-only changes (chmod, on filemode-honoring systems) count as changes;
#   the config-only exemption token covers them.
# - Stdin is drained, never parsed: decisions come from git state alone. The
#   exemption token the skill requires is a human audit trail, not hook input.
# - Known limit: only uncommitted work is visible. Code written and committed
#   inside one turn is past the hook's reach — the skill requires applying
#   test-or-justify BEFORE committing.
# - Tuning: adjust SRC_RE/TEST_RE_* in the repo's copy only. Rust is
#   deliberately absent from SRC_RE: inline #[cfg(test)] modules would always
#   wrong-block; add .rs back only if your Rust tests live in separate files.
set -u

cat >/dev/null 2>&1 || true   # drain stdin

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

head_sha=$(git rev-parse -q --verify HEAD 2>/dev/null) || head_sha=""
base=${head_sha:-$(git hash-object -t tree /dev/null)}

changed=$( { git -c core.quotepath=false diff --name-only --diff-filter=d -z "$base" -- 2>/dev/null | tr '\0\n' '\n_';
             git -c core.quotepath=false ls-files --others --exclude-standard -z 2>/dev/null | tr '\0\n' '\n_'; } \
           | sort -u | sed '/^$/d' )
[ -z "$changed" ] && exit 0

# --- Tunable per repo ------------------------------------------------------
# Code files the gate expects tests for (by extension):
SRC_RE='\.(py|ts|tsx|js|jsx|mjs|cjs|cs|java|go|rb|php|kt|kts|swift|c|cc|cpp|h|hpp|m|mm|scala|ex|exs)$'
# Test files that satisfy the gate (case-insensitive):
TEST_RE_CI='(^|/)(tests?|__tests__|specs?)(/|$)|(^|/)test_|\.(test|spec)s?\.|_tests?\.|_specs?\.|conftest\.py$'
# Case-sensitive extras (C#/JVM/Swift Foo{Test,Tests}.<ext> suffix convention):
TEST_RE_CS='Tests?\.(cs|java|kt|swift|scala)$'
# ---------------------------------------------------------------------------

tests=$( printf '%s\n' "$changed" | grep -Ei "$TEST_RE_CI"; \
         printf '%s\n' "$changed" | grep -E "$TEST_RE_CS" )
src=$( printf '%s\n' "$changed" | grep -Ei "$SRC_RE" \
       | grep -Evi "$TEST_RE_CI" | grep -Ev "$TEST_RE_CS" )

[ -z "$src" ] && exit 0        # nothing test-worthy changed
[ -n "$tests" ] && exit 0      # test changes accompany the code

gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
state="$gitdir/claude-test-gate-seen"
sig=$( { printf '%s\n' "$head_sha"; printf '%s\n' "$src"; } | git hash-object --stdin 2>/dev/null )
[ -n "$sig" ] || exit 0
[ -f "$state" ] && grep -qxF "$sig" "$state" && exit 0   # this state already nudged

# Persist the sig BEFORE blocking; if it cannot be persisted, fail open —
# blocking without memory would nag on every stop forever.
{ printf '%s\n' "$sig" >>"$state"; } 2>/dev/null || exit 0
if [ "$(wc -l <"$state" 2>/dev/null || echo 0)" -gt 100 ]; then
  { tail -n 100 "$state" >"$state.tmp.$$" && mv -f "$state.tmp.$$" "$state"; } 2>/dev/null \
    || rm -f "$state.tmp.$$" 2>/dev/null
fi

# JSON-safe, truncated file list: everything outside printable ASCII replaced,
# so invalid-UTF-8 filename bytes can never yield illegal JSON. 8 entries max.
list=$( printf '%s\n' "$src" | head -n 8 | LC_ALL=C sed -E 's/["\\]|[^ -~]/_/g' \
        | awk 'NR>1{printf ", "} {printf "%s", $0}' )
n=$( printf '%s\n' "$src" | wc -l | tr -d '[:space:]' )
[ "$n" -gt 8 ] && list="$list, +$((n-8)) more"

printf '{"decision":"block","reason":"test-gate: %s changed source file(s) have no accompanying test changes: %s. Per the test-gate skill (test-or-justify): add or extend unit tests covering the changed behavior (quality bar: test-craft), or state the exemption in your final report as test-gate: exempt(<generated|config-only|ui-glue|inline-tests|throwaway|no-infra>) - <one line of why>, then stop again. Never add an assertion-free test just to pass this gate."}\n' "$n" "$list"
exit 0
