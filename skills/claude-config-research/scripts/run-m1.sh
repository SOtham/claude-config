#!/usr/bin/env bash
# run-m1.sh - M1 trigger-recall (classification) baseline for the claude-config skill library.
#
# Measures, for each frozen corpus case, whether the model maps the task phrasing to the
# intended skill using ONLY the always-in-context skill descriptions. Tools are disabled and
# the answer is read straight from the returned JSON, so there is no tool-invocation confound
# and no transcript-flush race (both were real pitfalls - see experiment-log.md entry #3).
#
# This is the DESCRIPTION-recall instrument (does the description discriminate?). It is distinct
# from invocation-time behavior (whether the model actually emits a Skill call), which differs by
# tier and collides with bundled skills - see entry #3.
#
# Usage:   bash run-m1.sh <model-id> [outdir]
# Example: bash run-m1.sh claude-haiku-4-5-20251001
#          bash run-m1.sh claude-sonnet-5 /tmp/m1-sonnet
# Requires: the `claude` CLI. Override its path with CLAUDE=/full/path/to/claude.exe if not on PATH.
set -u
CLAUDE="${CLAUDE:-claude}"
command -v "$CLAUDE" >/dev/null 2>&1 || { echo "claude CLI not found; set CLAUDE=/path/to/claude(.exe)"; exit 2; }
MODEL="${1:?usage: run-m1.sh <model-id> [outdir]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CORPUS="$HERE/../references/trigger-cases.md"
# Run artifacts go to a TEMP dir by default, never inside the skill folder (they must not ship in the zip).
# Record the verdict in references/experiment-log.md; the raw per-case JSON is disposable.
OUT="${2:-${TMPDIR:-/tmp}/claude-m1/$(date +%Y%m%d-%H%M%S)-$MODEL}"; mkdir -p "$OUT"
NOTOOLS="Bash,Read,Glob,Grep,Edit,Write,Skill,WebFetch,WebSearch,Task,TodoWrite,NotebookEdit"
RES="$OUT/results.csv"; echo "num,type,expected,answer,verdict" > "$RES"

# Extract cases from the frozen markdown corpus: num|type|expected|phrasing
python - "$CORPUS" > "$OUT/cases.txt" <<'PY'
import re,sys
for line in open(sys.argv[1],encoding="utf-8"):
    m=re.match(r'\|\s*(\d+)\s*\|\s*(should-load|near-miss|discrimination)\s*\|\s*"(.*?)"\s*\|\s*(.*?)\s*\|',line)
    if m:
        num,typ,phr,exp=m.groups(); exp=exp.strip()
        if typ=="near-miss": exp="none"
        print(f"{num}|{typ}|{exp}|{phr}")
PY

pass=0; fail=0; total=0
while IFS='|' read -r num type expected phrasing; do
  [ -z "$num" ] && continue
  total=$((total+1))
  prompt="From the Skills available to you, output the EXACT name of the single best-matching skill for the user request below. If no skill clearly applies, output NONE. Do not use any tools; answer from the skill descriptions alone. Output only the skill name or NONE, nothing else.

User request: $phrasing"
  json="$OUT/case-$num.json"
  timeout 120 "$CLAUDE" -p "$prompt" --output-format json --model "$MODEL" \
     --disallowedTools "$NOTOOLS" --permission-mode default > "$json" 2>"$OUT/case-$num.err"
  if grep -q '"is_error":true' "$json"; then
    ans="(error)"; echo "$num,$type,$expected,$ans,ERROR" >> "$RES"
    printf "%-3s %-14s ERROR (see case-%s.json - e.g. rate/session limit)\n" "$num" "$type" "$num"; fail=$((fail+1)); continue
  fi
  ans=$(grep -oE '"result":"[^"]*"' "$json" | head -1 | sed -E 's/"result":"(.*)"/\1/' \
        | tr 'A-Z' 'a-z' | grep -oE '[a-z0-9-]+' | head -1)
  [ -z "$ans" ] && ans="(unparsed)"
  verdict="FAIL"
  case "$type" in
    should-load)    [ "$ans" = "$expected" ] && verdict="PASS" ;;
    near-miss)      [ "$ans" = "none" ] && verdict="PASS" ;;
    discrimination) exp=$(echo "$expected" | sed -E 's/ .*//'); [ "$ans" = "$exp" ] && verdict="PASS" ;;
  esac
  [ "$verdict" = "PASS" ] && pass=$((pass+1)) || fail=$((fail+1))
  echo "$num,$type,$expected,$ans,$verdict" >> "$RES"
  printf "%-3s %-14s exp=%-32s ans=%-32s %s\n" "$num" "$type" "$expected" "$ans" "$verdict"
done < "$OUT/cases.txt"
echo "--- M1 $MODEL: PASS=$pass FAIL=$fail of $total  ->  $RES"
