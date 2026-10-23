#!/usr/bin/env python3
"""Build a timesheet upload workbook from calendar meetings.

Usage:
  build_timesheet.py --template TimesheetUpload.xlsx --meetings meetings.json \
      --out OUT.xlsx [--export TimesheetExport.xlsx] [--tz-offset 2] \
      [--sentiment Neutral] [--worked-from Home]

meetings.json: [{"subject": str, "start": "2026-10-19T06:50:00", "end": "...T07:00:00"}]
start/end are UTC wall-clock strings exactly as the calendar tool returns them.

Rules: dates are taken in local time (UTC + tz-offset, default 2 = SAST, no DST);
duration is the scheduled length with a 15-minute floor; project/category are learned
from the export's history (fallback Apex > Meetings, flagged); billable comes from the
template's Lookup sheet; meetings already in the export (same date + description) are
skipped. Exit codes: 0 ok / nothing to do, 2 bad input or template.
"""
import argparse, datetime as dt, json, re, sys
from collections import Counter, defaultdict
from openpyxl import load_workbook
from openpyxl.worksheet.cell_range import MultiCellRange

HEADERS = ['Date', 'Project', 'Category', 'Hours', 'Minutes', 'Billable',
           'Description', 'TicketNumber', 'Sentiment', 'WorkedFrom']
DEFAULT_PAIR = ('R - Projects - Ninety One - Apex', 'Meetings')
# Calendar subject -> the description used in past timesheets. Edit to teach new aliases.
ALIASES = [
    (r'core platform.*stand\s*up', 'Core platform standup'),
    (r'scrum of scrums', 'Scrum of scrums'),
]


def norm(s):
    return re.sub(r'[^a-z0-9]', '', str(s or '').lower())


def clean_description(subject):
    s = re.sub(r'\s*\((weekly|daily|monthly)\)\s*', ' ', subject or '', flags=re.I).strip()
    for pat, desc in ALIASES:
        if re.search(pat, s, re.I):
            return desc
    return s


def fail(msg):
    print(f'error: {msg}', file=sys.stderr)
    sys.exit(2)


def read_lookup(wb):
    if 'Lookup' not in wb.sheetnames:
        fail('template has no Lookup sheet')
    pairs, project = {}, None
    for row in wb['Lookup'].iter_rows(min_row=2, values_only=True):
        project = row[0] or project
        if project and row[1]:
            pairs[(project, row[1])] = row[2]
    return pairs


def as_date(v):
    if isinstance(v, dt.datetime):
        return v.date().isoformat()
    return str(v)[:10]


def read_export(path):
    """Return (mapping norm_desc -> (project, category), counts (date, norm_desc) -> n)."""
    ws = load_workbook(path, read_only=True).worksheets[0]
    rows = ws.iter_rows(values_only=True)
    head = [norm(h) for h in next(rows)]
    try:
        ix = {k: head.index(k) for k in ('date', 'project', 'category', 'description')}
    except ValueError:
        fail('export is missing Date/Project/Category/Description columns')
    seen, wording, counts = defaultdict(Counter), defaultdict(Counter), Counter()
    for r in rows:
        if not r[ix['date']] or not r[ix['description']]:
            continue
        d = norm(r[ix['description']])
        seen[d][(r[ix['project']], r[ix['category']])] += 1
        wording[d][str(r[ix['description']]).strip()] += 1
        counts[(as_date(r[ix['date']]), d)] += 1
    learned = {d: (c.most_common(1)[0][0], wording[d].most_common(1)[0][0])
               for d, c in seen.items()}
    return learned, counts


def local_event(m, tz):
    f = lambda s: dt.datetime.fromisoformat(str(s)[:19])
    start, end = f(m['start']), f(m['end'])
    minutes = int((end - start).total_seconds() // 60)
    return (start + dt.timedelta(hours=tz)).date().isoformat(), minutes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--template', required=True)
    ap.add_argument('--meetings', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--export')
    ap.add_argument('--tz-offset', type=int, default=2)
    ap.add_argument('--sentiment', default='Neutral')
    ap.add_argument('--worked-from', default='Home')
    a = ap.parse_args()

    wb = load_workbook(a.template)
    ws = wb.worksheets[0]
    if [c.value for c in ws[1]][:len(HEADERS)] != HEADERS:
        fail(f'template headers differ from expected {HEADERS}')
    table = next(iter(ws.tables.values()), None)
    if table is None:
        fail('template sheet has no table')
    lookup = read_lookup(wb)
    learned, counts = read_export(a.export) if a.export else ({}, Counter())

    out_rows, skipped, flagged = [], [], []
    meetings = json.load(open(a.meetings, encoding='utf-8'))
    for m in sorted(meetings, key=lambda m: m['start']):
        date, minutes = local_event(m, a.tz_offset)
        if minutes <= 0:
            continue
        desc = clean_description(m['subject'])
        key = (date, norm(desc))
        if counts[key] > 0:
            counts[key] -= 1
            skipped.append((date, desc))
            continue
        pair, history_desc = learned.get(norm(desc), (None, None))
        desc = history_desc or desc  # reuse past wording so rows read consistently
        if pair is None or pair not in lookup:
            if pair is not None:
                flagged.append((date, desc, f'learned {pair} is not in the template Lookup'))
            else:
                flagged.append((date, desc, 'no history; defaulted to Apex > Meetings'))
            pair = DEFAULT_PAIR
        if pair not in lookup:
            fail(f'default pair {pair} is not in the template Lookup')
        mins = max(15, minutes)
        out_rows.append((date, pair[0], pair[1], mins // 60, mins % 60,
                         lookup[pair], desc))

    if not out_rows:
        print('nothing to import: no new accepted meetings')
        for s in skipped:
            print(f'skipped (already in export): {s[0]} {s[1]}')
        return

    for i, r in enumerate(out_rows, start=2):
        c = ws.cell(i, 1, dt.datetime.strptime(r[0], '%Y-%m-%d'))
        c.number_format = 'yyyy-mm-dd'
        for j, v in enumerate(r[1:], start=2):
            ws.cell(i, j, v)
        ws.cell(i, 8, None)
        ws.cell(i, 9, a.sentiment)
        ws.cell(i, 10, a.worked_from)
    last = 1 + len(out_rows)
    table.ref = f'A1:J{last}'
    if table.autoFilter:
        table.autoFilter.ref = f'A1:J{last}'
    for dv in ws.data_validations.dataValidation:
        col = re.match(r'[A-Z]+', str(dv.sqref)).group(0)
        dv.sqref = MultiCellRange(f'{col}2:{col}{last}')
    wb.save(a.out)

    per_day = Counter()
    for r in out_rows:
        per_day[r[0]] += r[3] * 60 + r[4]
    print(f'wrote {len(out_rows)} rows -> {a.out}')
    for d in sorted(per_day):
        print(f'  {d}: {per_day[d] // 60}h{per_day[d] % 60:02d}')
    for s in skipped:
        print(f'skipped (already in export): {s[0]} {s[1]}')
    for f in flagged:
        print(f'FLAG {f[0]} "{f[1]}": {f[2]}')


if __name__ == '__main__':
    main()
