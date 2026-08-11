#!/usr/bin/env bash
# context-guard.sh - PreToolUse advisory hook: warns before a tool call injects an
# avoidably large result into context. Registered in settings.json for Read|Bash.
#
# WHY: an audit of real session transcripts found Bash (41.6%) and Read (39.7%)
# together produced 81% of all tool-result bytes ever injected into context, and
# CLAUDE.md's prose rule against unbounded output did not hold on its own. This is
# the enforced-layer backstop for that rule.
#
# BEHAVIOUR: advisory only. It NEVER blocks - it emits `additionalContext` (which
# PreToolUse injects next to the tool result, per the hooks docs) and no
# `permissionDecision`, so the normal permission flow proceeds untouched.
#
# FAIL-OPEN GUARANTEE: every unknown, unparseable, or missing input path exits 0
# silently. A parsing miss must never produce a spurious warning or block a call -
# jq is not available in this environment, so JSON is parsed with sed and the
# decoded path is confirmed to exist on disk before any warning is emitted.
#
# Exit: always 0. Output: either nothing, or one JSON object on stdout.
# Requires Git Bash (GNU sed/stat) on Windows.
set -u

# Size at which a whole-file Read is worth a second thought. ~40KB is ~10K tokens.
THRESHOLD_BYTES="${CLAUDE_CONTEXT_GUARD_BYTES:-40000}"

input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0

# Emit an advisory and exit. Text is JSON-escaped by the caller's construction:
# we only ever interpolate integers and a basename with quotes/backslashes stripped.
emit() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$1"
  exit 0
}

tool=$(printf '%s' "$input" \
  | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -n 1)

case "$tool" in
  Read)
    # An explicit range means the caller already scoped the read - stay silent.
    printf '%s' "$input" | grep -q '"\(limit\|offset\)"[[:space:]]*:' && exit 0

    raw=$(printf '%s' "$input" \
      | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
      | head -n 1)
    [ -n "$raw" ] || exit 0

    # Decode the JSON string escapes that appear in Windows paths.
    path=$(printf '%s' "$raw" | sed -e 's/\\"/"/g' -e 's|\\/|/|g' -e 's/\\\\/\\/g')

    # Fail-open: if the decode did not yield a real file, say nothing.
    [ -f "$path" ] || exit 0

    bytes=$(wc -c < "$path" 2>/dev/null | tr -d ' ')
    case "$bytes" in ''|*[!0-9]*) exit 0 ;; esac
    [ "$bytes" -gt "$THRESHOLD_BYTES" ] || exit 0

    kb=$((bytes / 1024))
    tok=$((bytes / 4))
    name=$(basename "$path" | tr -d '"\\')
    emit "context-guard: ${name} is ~${kb}KB (~${tok} tokens) and is being read in full. If you need one region, re-read with offset/limit - a whole-file read of this size is the single most common avoidable context cost. If you genuinely need all of it, proceed."
    ;;

  Bash)
    cmd=$(printf '%s' "$input" \
      | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
      | head -n 1)
    [ -n "$cmd" ] || exit 0

    # Anything already piped through a limiter is bounded - stay silent.
    printf '%s' "$cmd" | grep -Eq '\|[[:space:]]*(head|tail)\b' && exit 0

    # Deliberately tiny, high-confidence set: each has an obvious bounded form.
    #
    # All three anchor at COMMAND POSITION - start of line, or just after ; & | (
    # - never after a bare space. A keyword sitting mid-line is almost always
    # prose or data (echo text, a commit message, a grep pattern), not an
    # invocation: 'echo "use find carefully"' must stay silent. grep works
    # line-by-line, so each line of a multi-line command anchors on its own ^.
    # The bias is deliberately conservative - a missed warning costs one command,
    # a false one trains the reader to ignore every warning.
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|()])[[:space:]]*git[[:space:]]+log\b' \
       && ! printf '%s' "$cmd" | grep -Eq '(-n[[:space:]]*[0-9]|--max-count|-[0-9]+)'; then
      emit "context-guard: 'git log' without a count limit can return unbounded output. Add -n (e.g. git log -n 20) unless you truly need full history."
    fi

    if printf '%s' "$cmd" | grep -Eq '(^|[;&|()])[[:space:]]*find\b' \
       && ! printf '%s' "$cmd" | grep -q -- '-maxdepth'; then
      emit "context-guard: 'find' without -maxdepth can walk an entire tree and flood context. Scope it with -maxdepth, or use the Glob tool instead."
    fi

    # The recursive flag must belong to THIS ls, not a later command in the same
    # line: [^;&|]* cannot cross a separator, so 'ls foo && grep -R bar' is silent.
    # Case matters - ls -r is reverse-sort, only -R recurses.
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|()])[[:space:]]*ls[[:space:]]+[^;&|]*(-[a-zA-Z]*R|--recursive)'; then
      emit "context-guard: 'ls -R' walks the whole tree and can flood context. Use the Glob tool for file discovery, or bound it with find -maxdepth."
    fi
    ;;
esac

exit 0
