#!/usr/bin/env bash
# run-all.sh - runner for this repo's deterministic test suites (tests/*.tests.sh).
#
# Conventions:
# - tests/<skill>.tests.sh     unit-tests skills/<skill>/scripts/*; the runner warns
#                              if the matching skill folder is gone (rename/retire rot).
# - tests/selftest-<tool>.tests.sh  tests repo tooling itself (e.g. the linter);
#                              exempt from the folder check.
# Each suite prints one [PASS]/[FAIL] line per case, uses ONLY temp-dir fixtures
# (never repo paths), and exits non-zero on any failure.
# This directory deliberately lives OUTSIDE skills\: sync.ps1 packages skill
# folders recursively, so anything under skills\ ships in the upload zips.
#
# Exit: 0 = every suite passed (warnings allowed), 1 = at least one suite failed.
# Requires Git Bash on Windows.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"

suites=0; failed=0
found=0
for t in "$HERE"/*.tests.sh; do
  [ -e "$t" ] || break
  found=1
  base=$(basename "$t" .tests.sh)
  case "$base" in
    selftest-*) ;;
    *) [ -d "$ROOT/skills/$base" ] \
         || echo "[WARN] $base.tests.sh has no matching skills/$base/ folder (renamed or retired skill?)" ;;
  esac
  echo "=== $base ==="
  suites=$((suites+1))
  bash "$t" || failed=$((failed+1))
done
[ "$found" -eq 1 ] || { echo "[FAIL] no *.tests.sh suites found in $HERE"; exit 1; }

echo "run-all: $suites suite(s), $failed failing"
[ "$failed" -eq 0 ] || exit 1
exit 0
