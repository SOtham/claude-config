#!/usr/bin/env bash
# timesheet-import.tests.sh - regression suite for
# skills/timesheet-import/scripts/build_timesheet.py.
#
# The script writes a workbook someone uploads to a timesheet system, so the cases
# that matter are: local-date conversion, the 15-minute floor, de-duplication against
# the export, project/category learned from history (and rejected when the template
# Lookup disagrees), and the table/validation ranges the upload relies on.
# Fixtures are generated in a temp dir (needs python + openpyxl); the repo and any
# real Downloads file are never touched. Exit 0 = all pass.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$(dirname "$HERE")/skills/timesheet-import/scripts/build_timesheet.py"
[ -f "$SCRIPT" ] || { echo "[FAIL] script not found: $SCRIPT"; exit 1; }
python -c "import openpyxl" 2>/dev/null || { echo "[FAIL] python with openpyxl is required"; exit 1; }
WORK=$(mktemp -d) || exit 1
trap 'cd /; rm -rf "$WORK"' EXIT
W=$(cygpath -m "$WORK" 2>/dev/null || echo "$WORK")
SCRIPT_W=$(cygpath -m "$SCRIPT" 2>/dev/null || echo "$SCRIPT")

P=0; F=0
ck(){ if [ "$1" = ok ]; then P=$((P+1)); echo "[PASS] $2"; \
      else F=$((F+1)); echo "[FAIL] $2${3:+ - got: $3}"; fi; }

# --- fixtures ----------------------------------------------------------------
python - "$W" <<'PY'
import sys, json
from openpyxl import Workbook
from openpyxl.worksheet.table import Table
from openpyxl.worksheet.datavalidation import DataValidation
w = sys.argv[1]
H = ['Date','Project','Category','Hours','Minutes','Billable','Description','TicketNumber','Sentiment','WorkedFrom']
def template(path, headers):
    wb = Workbook(); ws = wb.active; ws.title = 'TimesheetUpload'
    ws.append(headers); ws['F2'] = 'No'; ws['I2'] = 'Neutral'
    ws.add_table(Table(displayName='TimesheetEntry', ref='A1:J2'))
    for col in 'ABCDEFIJ':
        dv = DataValidation(type='list', formula1='"x"'); dv.add(f'{col}2'); ws.add_data_validation(dv)
    lk = wb.create_sheet('Lookup'); lk.append(['Project','Category','Billable'])
    for r in [('R - Projects - Ninety One - Apex','Development','Yes'),
              (None,'Meetings','Yes'),
              ('Remote Culture','Other','No'),
              ('Meetings and Reviews','One On One Attendance','No')]:
        lk.append(r)
    wb.save(path)
template(f'{w}/template.xlsx', H)
template(f'{w}/badheaders.xlsx', ['Date','Proj'] + H[2:])
wb = Workbook(); ws = wb.active
ws.append(['Date','Project','Category','Hours','Minutes','Billable','Description','Ticket Number','Sentiment','Worked From'])
for r in [('2026-10-19','R - Projects - Ninety One - Apex','Meetings','0','15','True','Core platform standup'),
          ('2026-10-05','Remote Culture','Other','0','45','False','Swarm down'),
          ('2026-10-13','Meetings and Reviews','One On One Attendance','1','0','False','One on one'),
          ('2026-10-06','Nowhere','Nothing','1','0','True','Bogus')]:
    ws.append(list(r) + ['', 'Neutral', 'Home'])
wb.save(f'{w}/export.xlsx')
M = [
 {"subject":"Core Platform - Daily Stand Up","start":"2026-10-19T06:50:00.0000000","end":"2026-10-19T07:00:00.0000000"},
 {"subject":"Core Platform - Daily Stand Up","start":"2026-10-20T06:50:00.0000000","end":"2026-10-20T07:00:00.0000000"},
 {"subject":"Scrum of Scrums (weekly)","start":"2026-10-20T09:00:00.0000000","end":"2026-10-20T10:00:00.0000000"},
 {"subject":"Swarm Down","start":"2026-10-21T13:00:00.0000000","end":"2026-10-21T13:45:00.0000000"},
 {"subject":"One on one","start":"2026-10-21T08:00:00.0000000","end":"2026-10-21T09:00:00.0000000"},
 {"subject":"Bogus","start":"2026-10-22T10:00:00.0000000","end":"2026-10-22T10:30:00.0000000"},
 {"subject":"Late call","start":"2026-10-19T22:30:00.0000000","end":"2026-10-19T23:00:00.0000000"},
 {"subject":"Zero length","start":"2026-10-22T12:00:00.0000000","end":"2026-10-22T12:00:00.0000000"},
]
json.dump(M, open(f'{w}/meetings.json','w'))
json.dump([M[0]], open(f'{w}/dup-only.json','w'))
PY

rows(){ python - "$1" <<'PY'
import sys
from openpyxl import load_workbook
ws = load_workbook(sys.argv[1]).worksheets[0]
for r in ws.iter_rows(min_row=2, values_only=True):
    print('|'.join([r[0].date().isoformat()] + [str(x) for x in r[1:7]] + [str(r[8]), str(r[9])]))
PY
}
APEX='R - Projects - Ninety One - Apex'

OUT="$W/out.xlsx"
log=$(python "$SCRIPT_W" --template "$W/template.xlsx" --export "$W/export.xlsx" --meetings "$W/meetings.json" --out "$OUT" 2>&1); rc=$?
[ $rc -eq 0 ] && [ -f "$OUT" ] && ck ok "T1 happy path writes the workbook" || ck no "T1 happy path writes the workbook" "rc=$rc $log"
R=$(rows "$OUT")

case "$R" in *"2026-10-19|$APEX|Meetings|0|15"*) ck no "T2 export duplicate is skipped (alias)" "$R";; *) ck ok "T2 export duplicate is skipped (alias)";; esac
case "$log" in *"skipped (already in export): 2026-10-19 Core platform standup"*) ck ok "T3 skip is reported";; *) ck no "T3 skip is reported" "$log";; esac
case "$R" in *"2026-10-20|$APEX|Meetings|0|15|Yes|Core platform standup|Neutral|Home"*) ck ok "T4 10-min standup floors to 0h15, Yes, defaults";; *) ck no "T4 10-min standup floors to 0h15" "$R";; esac
case "$R" in *"2026-10-20|$APEX|Meetings|0|30|Yes|Late call"*) ck ok "T5 22:30 UTC lands on next local day";; *) ck no "T5 22:30 UTC lands on next local day" "$R";; esac
case "$R" in *"2026-10-21|Remote Culture|Other|0|45|No|Swarm down"*) ck ok "T6 learned mapping Swarm down -> Remote Culture/Other/No";; *) ck no "T6 learned mapping Swarm down" "$R";; esac
case "$R" in *"2026-10-21|Meetings and Reviews|One On One Attendance|1|0|No|One on one"*) ck ok "T7 learned mapping one-on-one";; *) ck no "T7 learned mapping one-on-one" "$R";; esac
case "$R" in *"2026-10-20|$APEX|Meetings|1|0|Yes|Scrum of scrums"*) ck ok "T8 '(weekly)' stripped, scheduled hour kept";; *) ck no "T8 weekly alias" "$R";; esac
case "$log" in *'FLAG 2026-10-22 "Bogus"'*"not in the template Lookup"*) ck ok "T9 learned pair absent from Lookup is flagged";; *) ck no "T9 invalid learned pair flagged" "$log";; esac
case "$R" in *"2026-10-22|$APEX|Meetings|0|30|Yes|Bogus"*) ck ok "T10 invalid learned pair falls back to Apex Meetings";; *) ck no "T10 fallback" "$R";; esac
case "$R" in *Zero*) ck no "T11 zero-length event dropped" "$R";; *) ck ok "T11 zero-length event dropped";; esac
n=$(printf '%s\n' "$R" | grep -c .)
[ "$n" -eq 6 ] && ck ok "T12 exactly 6 rows written" || ck no "T12 exactly 6 rows written" "$n"

chk=$(python - "$OUT" <<'PY'
from openpyxl import load_workbook
ws = load_workbook(__import__('sys').argv[1]).worksheets[0]
t = next(iter(ws.tables.values()))
print(t.ref, sorted({str(d.sqref) for d in ws.data_validations.dataValidation}))
PY
)
case "$chk" in "A1:J7 ['A2:A7', 'B2:B7', 'C2:C7', 'D2:D7', 'E2:E7', 'F2:F7', 'I2:I7', 'J2:J7']") ck ok "T13 table and validations cover every row";; *) ck no "T13 table and validations extended" "$chk";; esac

# no export -> nothing de-duplicated, everything flagged-as-default where unknown
log2=$(python "$SCRIPT_W" --template "$W/template.xlsx" --meetings "$W/meetings.json" --out "$W/noexport.xlsx" 2>&1); rc=$?
[ $rc -eq 0 ] && rows "$W/noexport.xlsx" | grep -q '^2026-10-19|.*|Core platform standup' \
  && ck ok "T14 without an export nothing is skipped" || ck no "T14 without an export" "rc=$rc $log2"

# nothing new -> no file, exit 0
python "$SCRIPT_W" --template "$W/template.xlsx" --export "$W/export.xlsx" --meetings "$W/dup-only.json" --out "$W/none.xlsx" >"$W/none.log" 2>&1; rc=$?
[ $rc -eq 0 ] && [ ! -f "$W/none.xlsx" ] && grep -q 'nothing to import' "$W/none.log" \
  && ck ok "T15 no new meetings -> no file, clear message" || ck no "T15 no new meetings" "rc=$rc $(cat "$W/none.log")"

# bad template -> exit 2, no file
python "$SCRIPT_W" --template "$W/badheaders.xlsx" --meetings "$W/meetings.json" --out "$W/bad.xlsx" >"$W/bad.log" 2>&1; rc=$?
[ $rc -eq 2 ] && [ ! -f "$W/bad.xlsx" ] && grep -q 'headers differ' "$W/bad.log" \
  && ck ok "T16 changed template headers fail loudly (exit 2)" || ck no "T16 bad headers" "rc=$rc $(cat "$W/bad.log")"

echo "timesheet-import: $P passed, $F failed"
[ "$F" -eq 0 ]
