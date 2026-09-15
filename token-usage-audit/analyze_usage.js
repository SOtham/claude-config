const fs = require('fs');
const path = require('path');
const readline = require('readline');

const ROOT = (process.env.HOME || process.env.USERPROFILE).replace(/\\/g, '/') + '/.claude/projects';
const SINCE = new Date('2026-08-01T00:00:00Z').getTime();

// USD per million tokens. Intro Sonnet pricing active through 31 Aug 2026.
// cache write 1h = 2x base input, cache write 5m = 1.25x base input, cache read = 0.1x base input.
function priceFor(model) {
  const m = (model || '').toLowerCase();
  let base;
  if (m.includes('opus')) base = { in: 5, out: 25 };
  else if (m.includes('fable') || m.includes('mythos')) base = { in: 10, out: 50 };
  else if (m.includes('haiku')) base = { in: 1, out: 5 };
  else base = { in: 2, out: 10 }; // sonnet-5 intro pricing
  return {
    in: base.in, out: base.out,
    cw1h: base.in * 2, cw5m: base.in * 1.25, cr: base.in * 0.1,
  };
}

function findJsonlFiles(dir, out) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return; }
  for (const e of entries) {
    const full = path.join(dir, e.name).replace(/\\/g, '/');
    if (e.isDirectory()) findJsonlFiles(full, out);
    else if (e.isFile() && e.name.endsWith('.jsonl')) {
      let st;
      try { st = fs.statSync(full); } catch (e) { continue; }
      if (st.mtimeMs >= SINCE) out.push(full);
    }
  }
}

function classify(file) {
  const rel = file.slice(ROOT.length + 1);
  const segs = rel.split('/');
  const project = segs[0];
  if (segs.length === 2 && segs[1].endsWith('.jsonl')) {
    return { kind: 'main', project, sessionId: segs[1].replace(/\.jsonl$/, ''), parentSession: null, workflow: null };
  }
  const sessionId = segs[1];
  if (segs.includes('workflows')) {
    const wfIdx = segs.indexOf('workflows');
    const workflow = segs[wfIdx + 1];
    return { kind: 'workflow-agent', project, sessionId: segs[segs.length - 1].replace(/\.jsonl$/, ''), parentSession: sessionId, workflow };
  }
  if (segs.includes('subagents')) {
    return { kind: 'subagent', project, sessionId: segs[segs.length - 1].replace(/\.jsonl$/, ''), parentSession: sessionId, workflow: null };
  }
  return { kind: 'other', project, sessionId: segs[segs.length - 1].replace(/\.jsonl$/, ''), parentSession: sessionId, workflow: null };
}

function emptyTok() { return { input: 0, output: 0, cacheCreate: 0, cacheRead: 0, msgCount: 0 }; }
function addTok(a, u) {
  a.input += u.input_tokens || 0;
  a.output += u.output_tokens || 0;
  a.cacheCreate += u.cache_creation_input_tokens || 0;
  a.cacheRead += u.cache_read_input_tokens || 0;
  a.msgCount += 1;
}
function tokTotal(a) { return a.input + a.output + a.cacheCreate + a.cacheRead; }
function cost(a, model) {
  const p = priceFor(model);
  return (a.input * p.in + a.output * p.out + a.cacheCreate * p.cw1h + a.cacheRead * p.cr) / 1e6;
}

function primaryArgKey(name, input) {
  if (!input) return '';
  if (name === 'Read') return input.file_path || '';
  if (name === 'Edit') return input.file_path || '';
  if (name === 'Grep') return (input.pattern || '') + '|' + (input.path || '');
  if (name === 'Glob') return (input.pattern || '') + '|' + (input.path || '');
  if (name === 'Bash' || name === 'PowerShell') return (input.command || '').slice(0, 120);
  return JSON.stringify(input).slice(0, 120);
}

async function processFile(file, sessions, globals) {
  const meta = classify(file);
  const key = meta.project + '::' + (meta.parentSession || meta.sessionId);
  if (!sessions.has(key)) {
    sessions.set(key, {
      project: meta.project,
      sessionId: meta.parentSession || meta.sessionId,
      aiTitle: null,
      cwd: null,
      gitBranch: null,
      firstTs: null,
      lastTs: null,
      mainTokens: emptyTok(),
      delegatedTokens: emptyTok(),
      agentFileCount: 0,
      workflowIds: new Set(),
      modelsUsed: new Set(),
      toolCallCounts: new Map(),
      toolResultChars: new Map(),
      argCounts: new Map(), // tool|argkey -> count
      largeResults: [],
      promptJumps: [],
      lastTotalCtx: 0,
    });
  }
  const sess = sessions.get(key);
  const isMain = meta.kind === 'main';
  if (isMain) sess.aiTitle = sess.aiTitle; // no-op, set below on ai-title events
  if (!isMain) { sess.agentFileCount += 1; if (meta.workflow) sess.workflowIds.add(meta.workflow); }

  const toolUseNames = new Map(); // tool_use_id -> {name, input}
  let lastAssistantWasMain = isMain;

  const rl = readline.createInterface({ input: fs.createReadStream(file), crlfDelay: Infinity });
  for await (const line of rl) {
    if (!line.trim()) continue;
    let obj;
    try { obj = JSON.parse(line); } catch (e) { continue; }
    const ts = obj.timestamp ? Date.parse(obj.timestamp) : null;
    if (ts && ts < SINCE) continue;

    if (obj.type === 'ai-title' && isMain) {
      sess.aiTitle = obj.aiTitle;
    }
    if ((obj.type === 'assistant' || obj.type === 'system') && isMain) {
      if (obj.cwd && !sess.cwd) sess.cwd = obj.cwd;
      if (obj.gitBranch && !sess.gitBranch) sess.gitBranch = obj.gitBranch;
    }
    if (ts) {
      if (!sess.firstTs || ts < sess.firstTs) sess.firstTs = ts;
      if (!sess.lastTs || ts > sess.lastTs) sess.lastTs = ts;
    }

    if (obj.type === 'assistant') {
      const msg = obj.message || {};
      const model = msg.model;
      if (model) sess.modelsUsed.add(model);
      const usage = msg.usage;
      const bucket = isMain ? sess.mainTokens : sess.delegatedTokens;
      if (usage) {
        addTok(bucket, usage);
        const totalCtx = (usage.input_tokens || 0) + (usage.cache_creation_input_tokens || 0) + (usage.cache_read_input_tokens || 0);
        if (isMain) {
          if (sess.lastTotalCtx > 0) {
            const jump = totalCtx - sess.lastTotalCtx;
            if (jump > 25000) {
              sess.promptJumps.push({ ts: obj.timestamp, jump, totalCtx });
            }
          }
          sess.lastTotalCtx = totalCtx;
        }
        // global model/day totals
        const day = obj.timestamp ? obj.timestamp.slice(0, 10) : 'unknown';
        if (!globals.byDay.has(day)) globals.byDay.set(day, emptyTok());
        addTok(globals.byDay.get(day), usage);
        if (!globals.byModel.has(model)) globals.byModel.set(model, emptyTok());
        addTok(globals.byModel.get(model), usage);
        if (!globals.byProject.has(meta.project)) globals.byProject.set(meta.project, emptyTok());
        addTok(globals.byProject.get(meta.project), usage);
        addTok(isMain ? globals.mainTotal : globals.delegatedTotal, usage);
      }
      // record tool_use blocks for later correlation with tool_result
      const content = Array.isArray(msg.content) ? msg.content : [];
      for (const block of content) {
        if (block && block.type === 'tool_use') {
          toolUseNames.set(block.id, { name: block.name, input: block.input });
          sess.toolCallCounts.set(block.name, (sess.toolCallCounts.get(block.name) || 0) + 1);
          globals.toolCallCounts.set(block.name, (globals.toolCallCounts.get(block.name) || 0) + 1);
          const argKey = block.name + '|' + primaryArgKey(block.name, block.input);
          const scopedKey = key + '::' + argKey;
          sess.argCounts.set(argKey, (sess.argCounts.get(argKey) || 0) + 1);
        }
      }
    }

    if (obj.type === 'user') {
      const msg = obj.message || {};
      const content = Array.isArray(msg.content) ? msg.content : (typeof msg.content === 'string' ? [] : []);
      for (const block of content) {
        if (block && block.type === 'tool_result') {
          const info = toolUseNames.get(block.tool_use_id) || { name: 'unknown', input: null };
          let chars = 0;
          try { chars = JSON.stringify(block.content).length; } catch (e) { chars = 0; }
          sess.toolResultChars.set(info.name, (sess.toolResultChars.get(info.name) || 0) + chars);
          globals.toolResultChars.set(info.name, (globals.toolResultChars.get(info.name) || 0) + chars);
          globals.toolResultBytesTotal += chars;
          if (chars > 40000) {
            sess.largeResults.push({
              tool: info.name,
              arg: primaryArgKey(info.name, info.input),
              chars,
              approxTokens: Math.round(chars / 4),
              ts: obj.timestamp,
            });
          }
        }
      }
    }
  }
}

async function main() {
  const files = [];
  findJsonlFiles(ROOT, files);
  const sessions = new Map();
  const globals = {
    byDay: new Map(),
    byModel: new Map(),
    byProject: new Map(),
    mainTotal: emptyTok(),
    delegatedTotal: emptyTok(),
    toolCallCounts: new Map(),
    toolResultChars: new Map(),
    toolResultBytesTotal: 0,
    fileCount: files.length,
  };
  for (const f of files) {
    await processFile(f, sessions, globals);
  }

  // Post-process sessions: dominant model, cost, cache ratio, flags
  const sessionSummaries = [];
  for (const [key, s] of sessions.entries()) {
    const total = emptyTok();
    ['input', 'output', 'cacheCreate', 'cacheRead'].forEach(k => { total[k] = s.mainTokens[k] + s.delegatedTokens[k]; });
    const dominantModel = [...s.modelsUsed][0] || 'claude-sonnet-5';
    const totalCost = cost(s.mainTokens, dominantModel) + cost(s.delegatedTokens, dominantModel);
    const cacheableBase = total.cacheRead + total.cacheCreate + total.input;
    const cacheHitRate = cacheableBase > 0 ? total.cacheRead / cacheableBase : 0;
    const dupArgs = [...s.argCounts.entries()].filter(([k, c]) => c >= 3).sort((a, b) => b[1] - a[1]);
    sessionSummaries.push({
      project: s.project,
      sessionId: s.sessionId,
      aiTitle: s.aiTitle,
      cwd: s.cwd,
      gitBranch: s.gitBranch,
      firstTs: s.firstTs ? new Date(s.firstTs).toISOString() : null,
      lastTs: s.lastTs ? new Date(s.lastTs).toISOString() : null,
      models: [...s.modelsUsed],
      mainTokens: s.mainTokens,
      delegatedTokens: s.delegatedTokens,
      totalTokens: total,
      totalTokenSum: tokTotal(total),
      estCostUSD: Number(totalCost.toFixed(2)),
      cacheHitRate: Number(cacheHitRate.toFixed(3)),
      agentFileCount: s.agentFileCount,
      workflowCount: s.workflowIds.size,
      topToolCalls: [...s.toolCallCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8),
      topToolBytes: [...s.toolResultChars.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8).map(([n, c]) => [n, c, Math.round(c / 4)]),
      duplicateArgCalls: dupArgs.slice(0, 8),
      largeResults: s.largeResults.sort((a, b) => b.chars - a.chars).slice(0, 5),
      promptJumps: s.promptJumps.sort((a, b) => b.jump - a.jump).slice(0, 5),
    });
  }
  sessionSummaries.sort((a, b) => b.totalTokenSum - a.totalTokenSum);

  const grandTotal = emptyTok();
  ['input', 'output', 'cacheCreate', 'cacheRead'].forEach(k => { grandTotal[k] = globals.mainTotal[k] + globals.delegatedTotal[k]; });

  const out = {
    fileCount: globals.fileCount,
    sessionCount: sessions.size,
    grandTotal,
    grandTotalSum: tokTotal(grandTotal),
    mainTotal: globals.mainTotal,
    delegatedTotal: globals.delegatedTotal,
    estTotalCostUSD_sonnet: Number(cost(grandTotal, 'claude-sonnet-5').toFixed(2)),
    byDay: Object.fromEntries([...globals.byDay.entries()].sort()),
    byModel: Object.fromEntries(globals.byModel),
    byProject: Object.fromEntries([...globals.byProject.entries()].sort((a, b) => tokTotal(b[1]) - tokTotal(a[1]))),
    toolCallCounts: Object.fromEntries([...globals.toolCallCounts.entries()].sort((a, b) => b[1] - a[1])),
    toolResultChars: Object.fromEntries([...globals.toolResultChars.entries()].sort((a, b) => b[1] - a[1])),
    sessions: sessionSummaries,
  };
  process.stdout.write(JSON.stringify(out, null, 1));
}

main().catch(e => { console.error(e); process.exit(1); });
