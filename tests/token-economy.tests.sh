#!/usr/bin/env bash
# token-economy.tests.sh - regression suite for
# skills/token-economy/scripts/context-guard.sh (PreToolUse advisory hook).
#
# The hook runs on EVERY Read and Bash call in every repo, so the properties that
# matter most are the negative ones: it must stay silent on scoped calls, fail open
# on anything it cannot parse, and never emit a permissionDecision (which would
# block). Fixtures live in a temp dir only; the repo is never touched.
# Exit 0 = all pass.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(dirname "$HERE")/skills/token-economy/scripts/context-guard.sh"
[ -f "$HOOK" ] || { echo "[FAIL] hook not found: $HOOK"; exit 1; }
WORK=$(mktemp -d) || exit 1
trap 'cd /; rm -rf "$WORK"' EXIT

P=0; F=0
ck(){ if [ "$1" = ok ]; then P=$((P+1)); echo "[PASS] $2"; \
      else F=$((F+1)); echo "[FAIL] $2${3:+ - got: $3}"; fi; }
run(){ printf '%s' "$1" | bash "$HOOK" 2>/dev/null; }

# JSON-escape a path for embedding in a test fixture (backslash then quote).
esc(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

BIG="$WORK/big.cs"; head -c 60000 /dev/zero | tr '\0' 'x' > "$BIG"
SMALL="$WORK/small.md"; printf 'tiny\n' > "$SMALL"
SPACED="$WORK/with space.cs"; head -c 60000 /dev/zero | tr '\0' 'y' > "$SPACED"

rd(){ printf '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s"%s}}' "$(esc "$1")" "${2:-}"; }
bs(){ printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }

# --- Read guard: fires only on unscoped reads of genuinely large files ---------
o=$(run "$(rd "$BIG")")
case "$o" in *additionalContext*big.cs*) ck ok "T1 large unscoped read warns";; *) ck no "T1 large unscoped read warns" "${o:-SILENT}";; esac
o=$(run "$(rd "$BIG" ',"limit":100')")
[ -z "$o" ] && ck ok "T2 limit set stays silent" || ck no "T2 limit set stays silent" "$o"
o=$(run "$(rd "$BIG" ',"offset":50')")
[ -z "$o" ] && ck ok "T3 offset set stays silent" || ck no "T3 offset set stays silent" "$o"
o=$(run "$(rd "$SMALL")")
[ -z "$o" ] && ck ok "T4 small file stays silent" || ck no "T4 small file stays silent" "$o"
o=$(run "$(rd "$SPACED")")
case "$o" in *additionalContext*) ck ok "T5 path with spaces still warns";; *) ck no "T5 path with spaces still warns" "${o:-SILENT}";; esac

# --- fail-open: anything unparseable or absent must be silent -----------------
o=$(run "$(rd "$WORK/does-not-exist.cs")")
[ -z "$o" ] && ck ok "T6 missing file fails open" || ck no "T6 missing file fails open" "$o"
o=$(run '{"tool_name":"Read","tool_input":{"file_path":"'"$(esc "$WORK")"'"}}')
[ -z "$o" ] && ck ok "T7 directory instead of file fails open" || ck no "T7 directory instead of file fails open" "$o"
o=$(run 'not json at all')
[ -z "$o" ] && ck ok "T8 non-JSON input fails open" || ck no "T8 non-JSON input fails open" "$o"
o=$(printf '' | bash "$HOOK" 2>/dev/null)
[ -z "$o" ] && ck ok "T9 empty stdin fails open" || ck no "T9 empty stdin fails open" "$o"
o=$(run '{"tool_name":"Write","tool_input":{"file_path":"'"$(esc "$BIG")"'"}}')
[ -z "$o" ] && ck ok "T10 unrelated tool ignored" || ck no "T10 unrelated tool ignored" "$o"

# JSON \/ escaping is legal and must still resolve to the real file.
slashed=$(printf '%s' "$BIG" | sed 's|/|\\/|g')
o=$(run "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$slashed\"}}")
case "$o" in *additionalContext*) ck ok "T11 escaped forward slashes decode";; *) ck no "T11 escaped forward slashes decode" "${o:-SILENT}";; esac

# Windows path form with doubled backslashes - the real-world Read input shape.
if command -v cygpath >/dev/null 2>&1; then
  win=$(cygpath -w "$BIG")
  o=$(run "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$(esc "$win")\"}}")
  case "$o" in *additionalContext*) ck ok "T12 Windows backslash path decodes";; *) ck no "T12 Windows backslash path decodes" "${o:-SILENT}";; esac
else
  ck ok "T12 Windows backslash path decodes (skipped: no cygpath)"
fi

# --- Bash guard: narrow, high-confidence, each with an obvious bounded form ----
o=$(run "$(bs 'git log --oneline')")
case "$o" in *additionalContext*git*log*) ck ok "T13 unbounded git log warns";; *) ck no "T13 unbounded git log warns" "${o:-SILENT}";; esac
o=$(run "$(bs 'git log -n 20')")
[ -z "$o" ] && ck ok "T14 git log -n stays silent" || ck no "T14 git log -n stays silent" "$o"
o=$(run "$(bs 'git log --max-count=5')")
[ -z "$o" ] && ck ok "T15 git log --max-count stays silent" || ck no "T15 git log --max-count stays silent" "$o"
o=$(run "$(bs 'git log --oneline | head -20')")
[ -z "$o" ] && ck ok "T16 piped to head stays silent" || ck no "T16 piped to head stays silent" "$o"
o=$(run "$(bs 'find . -name "*.cs"')")
case "$o" in *additionalContext*maxdepth*) ck ok "T17 find without -maxdepth warns";; *) ck no "T17 find without -maxdepth warns" "${o:-SILENT}";; esac
o=$(run "$(bs 'find . -maxdepth 2 -name "*.cs"')")
[ -z "$o" ] && ck ok "T18 find -maxdepth stays silent" || ck no "T18 find -maxdepth stays silent" "$o"
o=$(run "$(bs 'echo findings; echo git logic')")
[ -z "$o" ] && ck ok "T19 substrings do not false-positive" || ck no "T19 substrings do not false-positive" "$o"
o=$(run "$(bs 'npm test')")
[ -z "$o" ] && ck ok "T20 ordinary command stays silent" || ck no "T20 ordinary command stays silent" "$o"

# --- contract: advisory only, never blocking, always exit 0 -------------------
o=$(run "$(rd "$BIG")")
case "$o" in *permissionDecision*) ck no "T21 never emits permissionDecision" "$o";; *) ck ok "T21 never emits permissionDecision";; esac
case "$o" in *'"hookEventName":"PreToolUse"'*) ck ok "T22 declares PreToolUse event";; *) ck no "T22 declares PreToolUse event" "$o";; esac
lines=$(printf '%s' "$o" | wc -l | tr -d ' ')
[ "$lines" -le 1 ] && ck ok "T23 emits a single JSON line" || ck no "T23 emits a single JSON line" "$lines lines"
printf '%s' "$(rd "$BIG")" | bash "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && ck ok "T24 exits 0 when warning" || ck no "T24 exits 0 when warning"
printf 'garbage' | bash "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && ck ok "T25 exits 0 on garbage" || ck no "T25 exits 0 on garbage"

# --- threshold is tunable without editing the script -------------------------
# $SMALL is 5 bytes: a threshold of 2 must warn, and the default 40000 must not.
o=$(export CLAUDE_CONTEXT_GUARD_BYTES=2; run "$(rd "$SMALL")")
case "$o" in *additionalContext*) ck ok "T26 threshold env override lowers the bar";; *) ck no "T26 threshold env override lowers the bar" "${o:-SILENT}";; esac
o=$(export CLAUDE_CONTEXT_GUARD_BYTES=999999; run "$(rd "$BIG")")
[ -z "$o" ] && ck ok "T27 threshold env override raises the bar" || ck no "T27 threshold env override raises the bar" "$o"

echo "token-economy suite: $P passed, $F failed"
[ "$F" -eq 0 ] || exit 1
exit 0
