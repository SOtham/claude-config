# Ready-to-run: interactive-UI skill-loading check (entry #3 follow-up c)

**Status: run 2026-07-10, tier-split complete — see experiment-log entry #11 + addendum.** Headline: interactive UI auto-loaded `root-cause` at BOTH the top tier and the lightweight tier (2/2 should-load; near-miss clean; probe 2 skipped) — **a surface effect, tier ruled out**. Scriptable surfaces remain 0/9. Original protocol below for reruns. Needs a human at the real Claude Code UI (terminal or IDE) — every scriptable surface is already measured: **0/9 unscaffolded loads** (authoritative itemized tally: experiment-log entry #10 correction; spans subagents, headless restricted, and headless full-tool in-repo — the one partial exception is the restricted-tools pilot recorded in entry #3's correction, 2/3). This checks the one surface a script cannot drive: your own interactive sessions. ~10 minutes. Run the three probes back-to-back with no other sessions in between — the detection snippet samples the newest transcripts.

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

5. Record the outcome as a dated entry in `experiment-log.md`: per phrasing, which skill (if any) loaded. Compare against the scriptable-surface tally (0/9, entry #10 correction) and the restricted-tools pilot (2/3, entry #3 correction).

**Interpretation:** if the interactive UI also shows ~0 natural loads at your default tier, the scaffold / explicit `/name` invocation doctrine (entries #6–#10) extends to every surface, and CLAUDE.md's routing table is doing the heavy lifting only when a session bothers to consult it. If interactive loads are markedly better, surface differences matter and the uplift skill's Phase 0 should say so.

## Provenance

Written 2026-07-10. Baselines: experiment-log entries #6 (subagent 0/2 + clean near-miss), #8 (headless 2/3 with reminder, no flip; cumulative bare subagent loads 0/4 per #8's correction; all-surface tally 0/9 per #10's). Detection instrument: `claude-config-validation` §2.
