# Trigger-recall case set — v1, frozen 2026-07-08

The fixed corpus for measuring whether each skill's `description` fires on realistic task phrasings. Derived from the actual frontmatter descriptions of the 25 `SKILL.md` files on disk in `C:\Dev\claude-config\skills` on 2026-07-08 (every description read verbatim before writing its cases).

**Rules of use**

1. Run protocol is owned by `claude-config-validation` §3: one phrasing per **fresh** session, typed as a natural task; never type `/<name>`, never mention skills. Detect loads with the transcript instrument in `claude-config-validation` §2.
2. This file is the frozen corpus — **results never go here.** Record run results (dated, pass/fail per case number) in the experiment log (`references\experiment-log.md`) at program level, or in the tested skill's `evals.md` per `claude-config-validation` §7.
3. Append new cases with new numbers; **never renumber or reword existing cases** — comparability across runs depends on the corpus being identical.
4. A `near-miss` case passes when **no** skill loads. A `discrimination` case passes only when the expected skill loads AND the named rival does not.

## Cases

| # | Type | Task phrasing (typed verbatim as the user request) | Expected skill | Probes |
| --- | --- | --- | --- | --- |
| 1 | should-load | "Add retry with exponential backoff to the fetchUsers call in this service" | writing-code | implementing a fix |
| 2 | should-load | "I want to migrate this app's REST layer to gRPC — lay out the plan first" | architect | migration, plan before large change |
| 3 | should-load | "I have a rough idea for a CLI tool that organizes my downloads folder, but I'm not sure what it should actually do" | brainstorm | vague greenfield request |
| 4 | should-load | "Write unit tests for the parser module, TDD style" | test-craft | writing tests, TDD |
| 5 | should-load | "The nightly build started failing after yesterday's merge and I can't tell why" | root-cause | regression investigation |
| 6 | should-load | "This 800-line class works fine, but split it up without changing what it does" | refactor-safely | restructuring working code |
| 7 | should-load | "Split my working-tree changes into clean commits and open a PR" | shipping | commits, PR prep |
| 8 | should-load | "I just cloned this repo and have never seen the codebase — help me find where things live" | recon | unfamiliar codebase |
| 9 | should-load | "Write a README for this library with a quickstart and an API section" | doc-craft | writing documentation |
| 10 | should-load | "This repo has no CLAUDE.md — set up the Claude files it needs" | repo-setup | missing repo setup |
| 11 | should-load | "This monorepo is huge — explore it without blowing the context budget" | token-economy | broad exploration, context discipline |
| 12 | should-load | "Fan this analysis out to a few subagents in parallel, one per module" | orchestrate | spawning subagents |
| 13 | should-load | "Poll the deploy status every 10 minutes until it goes green" | loops | polling on an interval |
| 14 | should-load | "Review the system prompt for my support chatbot — it keeps ignoring the tone rules" | prompt-craft | reviewing a prompt |
| 15 | should-load | "I have to stop for today — capture where we are so tomorrow's session can pick this up" | handoff | transferring session state |
| 16 | should-load | "Should this new rule live in CLAUDE.md or in settings.json?" | claude-config-architecture | placing a rule in the layer split |
| 17 | should-load | "I want to tweak the wording of one of my personal skills — what's the process before I touch the file?" | claude-config-change-control | gating a config edit |
| 18 | should-load | "Draft a new skill for database-migration discipline in my personal skill library" | claude-config-skill-authoring | creating a skill here |
| 19 | should-load | "When my project settings.json and my user settings.json disagree, which one wins?" | claude-config-platform-reference | settings precedence fact |
| 20 | should-load | "New laptop — rebuild my ~/.claude symlinks and get my skills uploaded to claude.ai again" | claude-config-distribution | new machine, rebuild + upload |
| 21 | should-load | "My repo-setup skill stopped auto-loading and /repo-setup is missing from the command list" | claude-config-debugging | skill not loading, /name missing |
| 22 | should-load | "I changed a skill's description — prove it still loads before I re-upload the zip" | claude-config-validation | trigger test evidence |
| 23 | should-load | "I only have the lightweight model available today, but this refactor still has to meet full standard" | claude-config-model-uplift | cheaper tier doing real work |
| 24 | should-load | "How would we actually measure whether these skills trigger, instead of eyeballing it?" | claude-config-research | measurement over vibes |
| 25 | discrimination | "This async test is flaky — passes locally, fails in CI about a third of the time" | test-craft (not root-cause) | test-craft names async flakiness fixes |
| 26 | discrimination | "claude.ai rejected my skill zip when I tried to upload it" | claude-config-debugging (not claude-config-distribution) | debugging names upload rejected |
| 27 | discrimination | "Which flags does Claude Code headless mode support for JSON output?" | claude-config-platform-reference (not claude-config-research) | platform fact, not eval design |
| 28 | near-miss | "What's the capital of Australia?" | none | pure trivia baseline |
| 29 | near-miss | "Explain how git rebase works under the hood" | none | knowledge question near shipping's git keywords |
| 30 | near-miss | "Write a haiku about debugging" | none | contains "debugging" keyword, zero method need |
| 31 | near-miss | "Uninstall Claude Code from this machine" | none | near distribution's machine/setup keywords; nothing owns uninstall |
| 32 | near-miss | "Convert this JSON blob to YAML for me" | none | one-off mechanical transform; probes writing-code overtrigger |
| 33 | should-load | "Check whether my dist zips have gone stale and my ~/.claude links are still healthy" | claude-config-diagnostics | structural health check, stale zips |
| 34 | should-load | "My autonomous watch loop never stops and keeps double-posting the same comment — what discipline is it missing?" | loops | stop condition, idempotent body (appended 2026-07-09 for the arm-B `loops` description, entry #4) |

## Out of scope

- Bundled/official skills (`/code-review` etc.) — this library deliberately does not own them (README doctrine).

## Provenance

Frozen 2026-07-08 from the descriptions on disk that day. If any description changes, do NOT edit old cases — the changed skill's cases become the A/B material for the Step 3 experiment (`SKILL.md` §5), and new cases are appended.
