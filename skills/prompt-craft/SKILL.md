---
name: prompt-craft
description: Prompt engineering method for system prompts, CLAUDE.md files, skills, agents, and LLM app prompts - structure, examples, success criteria, eval loop. Use when writing or reviewing any prompt.
---

# Prompt Craft

Method for writing prompts of every kind: system prompts for LLM apps, CLAUDE.md instruction files, skills, agent definitions, and one-shot task prompts. A prompt is a program executed by a probabilistic interpreter — write it like one.

## Universal principles

1. **Be explicit; motivate rules.** "Answer in ≤3 sentences because output is shown on a phone" beats "be brief". Models generalize from the why.
2. **Show, don't only tell.** One or two realistic input→output examples outperform paragraphs of description. Make examples match the wanted format *exactly* — the model imitates them over the prose.
3. **Positive instructions.** Say what to do, not only what to avoid ("write plain prose" beats "don't use bullet points").
4. **Give an out.** State what to do under uncertainty ("if the answer isn't in the context, say so") — otherwise the model improvises.
5. **Structure beats length.** Use headed sections or XML-style tags to separate role, context, task, constraints, and output format. Put the output contract last and make it concrete: schema, template, or example.
6. **Order for caching.** Stable content (role, rules, reference material) first; per-request content (user input, retrieved docs) last.
7. **One prompt, one job.** If a prompt must extract *and* judge *and* rewrite, split it into stages or explicit numbered steps.

## Per-artifact guidance

**System prompts (LLM apps)** — define role and audience, hard constraints, tool-use rules, refusal/uncertainty behavior, output contract. Test adversarially: empty input, off-topic input, injection attempts.

**CLAUDE.md / instruction files** — facts and standing constraints only: build commands, conventions, boundaries. Every line is a permanent tax on every request, so keep it short and move procedures into skills. Write rules as MUST/SHOULD with the reason attached.

**Skills (SKILL.md)** — the `description` is the trigger: front-load *when to use it* with concrete verbs and keywords; keep it ≤200 chars for claude.ai compatibility. The body is the procedure: numbered steps, decision rules, anti-patterns. Long reference material goes in supporting files the body points to, so it loads only when needed.

**Agent definitions** — role, allowed tools (least privilege), and — most important — the exact output contract, since the agent's final message is all the caller receives. State what the agent must NOT do; scope creep is the default failure.

## The eval loop

Never ship a prompt untested.

1. Collect 5–10 real cases, including 2–3 hard or edge ones, *before* writing.
2. Draft → run all cases → read the failures.
3. Fix by diagnosis, not decoration: find which instruction was missing or contradicted, change that one thing, re-run everything (fixes regress other cases constantly).
4. When behavior keeps drifting, the instructions probably conflict — hunt for the contradiction before adding more rules.
5. Cut anything that isn't earning its tokens; shorter prompts are easier to follow and to debug.
