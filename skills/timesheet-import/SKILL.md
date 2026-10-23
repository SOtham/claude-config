---
name: timesheet-import
description: Build this week's timesheet upload from accepted Teams meetings - calendar, template, export dedupe, Neutral/Home. Use when asked to fill, import or create my timesheet from my calendar.
---

# Timesheet Import

Turn this week's accepted calendar meetings into a filled copy of the timesheet upload template. Meetings only: never invent development or analysis hours, and never hand-build the workbook — the script owns the template rules.

## Step 1 — Find the inputs (Downloads)

- Template: exactly `TimesheetUpload.xlsx` (blank, has the `Lookup` sheet). Missing → stop and ask; do not guess a layout.
- History: the newest `TimesheetExport*.xlsx`. It supplies learned project/category and the de-dupe list. Missing → continue without it and say so.
- Range: Monday of the current week through today. Never ask for dates.

## Step 2 — Pull the calendar

1. `outlook_calendar_search`: `query: "*"`, `afterDateTime` Monday 00:00, `beforeDateTime` tomorrow 00:00, `order: "oldest"`, `limit: 25`; repeat with `offset` = `nextOffset` until no more results. Output often exceeds the token cap and is saved to a file — read it with python, not the Read tool.
2. Keep an event only if `isCancelled` is false, `isAllDay` is false and `showAs` is `busy`. Why: the search returns no response status; `busy` = accepted or organised by me, `tentative` = unresponded/tentative invite, `free` = informational (verified 2026-10-23 against full event reads). Never read events one by one to double-check — that is the expensive path.
3. Write `meetings.json` in a scratch dir: `[{"subject","start","end"}]`, times exactly as returned (UTC wall-clock).

## Step 3 — Build

Run from a scratch dir (PowerShell or bash; plain `python`, not `-I`, because `-I` hides the user-site openpyxl):

```
python <skill>/scripts/build_timesheet.py --template ~/Downloads/TimesheetUpload.xlsx --export <newest export> --meetings meetings.json --out ~/Downloads/TimesheetUpload_<from>_to_<to>.xlsx
```

Defaults: Sentiment `Neutral`, Worked From `Home` (`--sentiment`, `--worked-from` only if the user says otherwise this run). The script applies: local dates (UTC+2), 15-minute floor, scheduled duration otherwise, billable from `Lookup`, skip of meetings already in the export, project/category from export history (fallback Apex > Meetings, flagged), output wording taken from history.

## Step 4 — Report

State per-day totals, what was skipped as already logged, and every `FLAG` line (unknown meeting or learned pair the template rejects) so the user can confirm or correct the project/category. Exit 2 = template or export layout changed: report the message, do not patch around it. To teach a calendar-name → description alias, add it to `ALIASES` in the script.

## Anti-patterns

- Including `tentative` meetings, or "accepted" guessed from attendee lists.
- Adding non-meeting hours the user told you to ignore.
- Building the xlsx with ad-hoc code — it drops the table range, validations and `Yes/No` billable format the upload needs.
- Treating a changed template as a reason to improvise a mapping.

## Provenance and maintenance

Written 2026-10-23 from a manual run. Re-verify before trusting:
- Template headers/billable format: `python -c "import openpyxl;print([c.value for c in openpyxl.load_workbook(r'<template>').worksheets[0][1]])"`
- Script behavior: `bash tests/timesheet-import.tests.sh` (repo `tests\`, not shipped in the zip)
- `showAs` = acceptance proxy: read one tentative and one busy event with `read_resource` and compare the user's own `responseStatus`.
