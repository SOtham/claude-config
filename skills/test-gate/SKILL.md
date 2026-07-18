---
name: test-gate
description: Test-or-justify gate - new code ships with tests or a stated exemption; per-repo Stop hook + installer. Use when the test-gate hook fires, deciding if a change may skip tests, or adding it to a repo.
---

# Test Gate

New or changed production code ships with unit tests in the same change, or with an explicitly stated exemption — never silently without either. This skill owns that policy and its per-repo enforcement hook; *how* to write good tests is `test-craft`'s job. Enforcement exists only in repos where the hook is installed (Section 3); elsewhere this skill loads via explicit invocation or install requests.

## 1. The rule: test-or-justify

Apply before declaring done — and **before committing**: the hook can only see uncommitted work.

1. List the source files you changed.
2. For each: either **tests accompany it** (new or extended, covering the changed behavior), or **exactly one exemption below applies — state it in your final report** as `test-gate: exempt(<category>) - <one line of why>`.
3. Silent skipping is never allowed. "Ran out of time" is not an exemption.

| Category | Applies when |
| --- | --- |
| `generated` | File is produced by a tool and regenerated, never hand-edited |
| `config-only` | Change alters values, not logic (constants, JSON, styles) |
| `ui-glue` | Thin markup/wiring with no branching; visual check is the real test (see `verify`) |
| `inline-tests` | Tests live inside the changed source file (Rust `#[cfg(test)]`, doctests) and were updated with it |
| `throwaway` | Spike or script explicitly not going to production |
| `no-infra` | Repo has no test framework — say so and propose adding one; don't hand-roll |

Judgment line: logic that branches, parses, calculates, or touches money, permissions, or time MUST be tested (test-craft's pays-most list); pure wiring MAY be exempted. When in doubt, test.

## 2. Responding to the hook

A `test-gate` block at stop means uncommitted source changes carry no accompanying test changes. Two honest moves:

- Write or extend the tests now — method and quality bar in `test-craft`; or
- State the Section 1 exemption token in your final report, then stop. The hook nudges at most once per (commit, changed-file-set), so the next stop passes; the token is the human audit trail — the hook does not parse it.

Never add an assertion-free test to silence the gate, and never edit the hook's patterns mid-task to make your own change pass.

## 3. Installing the gate in a repo (opt-in, deliberate)

In a team repo, propose these as a PR — other people's sessions will run the hook (`repo-setup` judgment).

1. Copy `scripts/test-gate.sh` from this skill folder to the repo's `.claude/hooks/test-gate.sh`, and copy this skill folder into the repo's `.claude/skills/` — the block reason and CLAUDE.md line point at the skill, and neither teammates' local sessions nor claude.ai web sessions can see your `~/.claude` copy (`repo-setup`). Solo, local-only repo: the skill copy may be skipped.
2. Keep LF endings: add `*.sh text eol=lf` to `.gitattributes` if absent; check `git ls-files --eol .claude/hooks/test-gate.sh` and run `git add --renormalize .claude/hooks/test-gate.sh` if it reports crlf.
3. Merge into the repo's `.claude/settings.json`:

   ```json
   {
     "hooks": {
       "Stop": [
         { "hooks": [ { "type": "command",
             "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/test-gate.sh\"",
             "timeout": 15 } ] }
       ]
     }
   }
   ```

   Very large repo? Raise `timeout` (units: seconds) — a hook killed at its timeout is silently inert.

4. Add one line to the repo's CLAUDE.md: `New/changed code ships with unit tests or a stated exemption (test-or-justify) — the test-gate Stop hook enforces this; doctrine in the test-gate skill.`
5. Verify: change a source file, end the turn — expect one block; add a test or state the token and stop — expect the pass (the pass comes from the once-per-signature memory, not from the token — Section 2).

## How the hook works

Deterministic bash Stop hook (needs Git Bash on Windows); silent exit 0 whenever it does not apply — or when it cannot persist its once-per-signature memory (it fails open rather than nag unboundedly; see the script header). It classifies uncommitted work (staged + unstaged + untracked; deletions excluded) with tunable regexes at the top of the script, and blocks at most once per (commit, changed-source-set) signature, remembered under `.git/` per worktree. Full mechanics and known limits live in the script's header comment — read it before tuning. The load-bearing limit: work committed in the same turn it was written is past the hook's reach, which is why Section 1 applies before committing.

## Anti-patterns

- An assertion-free test written to pass the gate — falsified evidence (`test-craft`'s iron rule); worse than a stated exemption.
- Exempting by habit: if most changes end up justified, the repo's patterns are wrong or the policy is dead — fix the script's constants or remove the hook honestly.
- Installing the hook in user-level settings: repos without test infra would nag forever; it is per-repo by design.
- Treating the gate as the quality bar: it checks that tests *exist*; quality lives in `test-craft`, risk judgment in Section 1.
