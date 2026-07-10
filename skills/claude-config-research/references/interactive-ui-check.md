# Ready-to-run: interactive-UI skill-loading check (entry #3 follow-up c)

**Status: not yet run** (as of 2026-07-10). Needs a human at the real Claude Code UI (terminal or IDE) — subagent-harness and headless surfaces are already measured (entries #6/#8: 0/3 natural-phrasing loads in subagents; headless inconsistent). This checks the one surface a script cannot drive: your own interactive sessions. ~10 minutes.

## Protocol

1. Open a **fresh** interactive Claude Code session in any repo (or an empty folder).
2. Type each phrasing below as your first message in its own fresh session — naturally, never mentioning skills:
   - "The nightly build started failing after yesterday's merge and I can't tell why." (expected: `root-cause`)
   - "Add retry with exponential backoff to the fetchUsers call in this service" — in a repo that has some service file (expected: `writing-code`)
   - "What's the capital of Australia?" (expected: none)
3. Let each session respond, then end it.
4. Detect loads from the transcripts (PowerShell):

```powershell
Get-ChildItem "$HOME\.claude\projects" -Recurse -Filter *.jsonl | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object { "{0}: {1}" -f $_.Name, ((Select-String -Path $_.FullName -Pattern '"skill":"([a-z-]+)"' -AllMatches).Matches.Value -join ',') }
```

5. Record the outcome as a dated entry in `experiment-log.md`: per phrasing, which skill (if any) loaded. Compare against the subagent baseline (0/2 should-load) and headless baseline (1/2).

**Interpretation:** if the interactive UI also shows ~0 natural loads at your default tier, the scaffold / explicit `/name` invocation doctrine (entries #6–#8) extends to every surface, and CLAUDE.md's routing table is doing the heavy lifting only when a session bothers to consult it. If interactive loads are markedly better, surface differences matter and the uplift skill's Phase 0 should say so.

## Provenance

Written 2026-07-10. Baselines: experiment-log entries #6 (subagent 0/2 + clean near-miss), #8 (headless 2/3 with reminder, no flip; cumulative bare subagent loads 0/3). Detection instrument: `claude-config-validation` §2.
