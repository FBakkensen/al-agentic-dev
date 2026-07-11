// al-kanban pure logic: frontmatter parsing, advance mapping, column
// placement, folder discovery, snapshot building. SDK-free so it loads under
// plain `node --test` as well as the extension host.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join, dirname, resolve, basename } from "node:path";

// ---------------------------------------------------------------------------
// Frontmatter parser — hand-rolled for exactly the task-file contract:
// flat scalars, inline lists ([T-001, T-002]), block lists of "- " strings.
// Unknown fields pass through. Any malformation throws → "unparseable" card.
// ---------------------------------------------------------------------------

export function parseFrontmatter(text) {
  const lines = text.split(/\r?\n/);
  if (lines[0] !== "---") return null; // no frontmatter (e.g. 000-feature.md)
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") { end = i; break; }
  }
  if (end === -1) throw new Error("frontmatter never closed");
  const fm = {};
  let i = 1;
  while (i < end) {
    const line = lines[i];
    if (line.trim() === "") { i++; continue; }
    const colon = line.indexOf(":");
    if (colon === -1 || /^\s/.test(line)) throw new Error(`bad frontmatter line: ${line}`);
    const key = line.slice(0, colon).trim();
    let value = line.slice(colon + 1).trim();
    if (value === "") {
      // block list: following lines are "- item" (optional indent)
      const items = [];
      let j = i + 1;
      while (j < end && /^\s*- /.test(lines[j])) {
        items.push(lines[j].replace(/^\s*- /, "").trim());
        j++;
      }
      if (items.length === 0) throw new Error(`empty value for key: ${key}`);
      fm[key] = items;
      i = j;
      continue;
    }
    if (value.startsWith("[")) {
      if (!value.endsWith("]")) throw new Error(`unclosed inline list for key: ${key}`);
      fm[key] = value.slice(1, -1).split(",").map((s) => s.trim()).filter(Boolean);
    } else {
      fm[key] = value;
    }
    i++;
  }
  return { fm, body: lines.slice(end + 1).join("\n") };
}

// ---------------------------------------------------------------------------
// Advance mapping: (kind, status, phase) → next skill, or null.
// ---------------------------------------------------------------------------

export function computeAdvance(t) {
  const { kind, status, phase, reviewClean, recordYes } = t;
  if (kind === "technical") {
    if (status === "ready" && !phase) return "al-refine";
    if (status === "ready-for-implementation" && phase === "refined") return "al-implement";
    if (status === "done" && phase === "implemented") return "al-refactor";
    if (status === "done" && phase === "refactored") return "al-mutate";
    return null;
  }
  if (kind === "verify") {
    if (status === "ready" && reviewClean && !phase) return "al-refine";
    if (status === "ready-for-verification" && phase === "planned")
      return recordYes ? "al-page-script" : "al-user-verification";
    if (status === "ready-for-verification" && phase === "page-scripted")
      return "al-user-verification";
    return null;
  }
  if (kind === "provision" && status === "ready") return "al-provision";
  if (kind === "breaking-change" && status === "ready") return "al-validate-breaking-changes";
  return null;
}

// ---------------------------------------------------------------------------
// Column placement (server-side, so all board instances agree).
// ---------------------------------------------------------------------------

export function technicalColumn(t) {
  if (t.phase === "refined") return "Refined";
  if (t.phase === "implemented") return "Implemented";
  if (t.phase === "refactored") return "Refactored";
  if (t.phase === "mutated") return "Mutated";
  // no phase: blocked-at-scope-time and ready both land in Ready
  return "Ready";
}

export function verifyColumn(t) {
  if (t.status === "done") return "Verified";
  if (t.phase === "page-scripted") return "Page-scripted";
  if (t.phase === "planned") return "Planned";
  if (t.status === "ready" && t.reviewClean) return "Opened by review";
  return "Waiting on gate";
}

// ---------------------------------------------------------------------------
// Folder discovery: explicit input → branch-matching specs/*/tasks →
// most recently modified specs/*/tasks → empty state naming searched paths.
// ---------------------------------------------------------------------------

function gitBranch(cwd) {
  try {
    return execFileSync("git", ["branch", "--show-current"], {
      cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "";
  }
}

export function discoverTasksFolder(workingDirectory, inputFolder) {
  const searched = [];
  if (inputFolder) {
    const abs = resolve(workingDirectory, inputFolder);
    searched.push(abs);
    if (existsSync(abs)) return { folder: abs, searched };
    return { folder: null, searched };
  }
  const specsRoot = join(workingDirectory, "specs");
  searched.push(join(specsRoot, "*", "tasks"));
  if (!existsSync(specsRoot)) return { folder: null, searched };
  const candidates = readdirSync(specsRoot, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => join(specsRoot, d.name, "tasks"))
    .filter((p) => existsSync(p));
  if (candidates.length === 0) return { folder: null, searched };
  const branch = gitBranch(workingDirectory);
  if (branch) {
    const match = candidates.find((p) => {
      const name = basename(dirname(p)); // NNN-slug
      const slug = name.replace(/^\d+-/, "");
      return branch === name || branch.includes(slug);
    });
    if (match) return { folder: match, searched };
  }
  // Rank by newest task file inside, not folder mtime (adding a file does not
  // touch the folder mtime on all platforms).
  const newestTaskMtime = (p) => {
    try {
      const mds = readdirSync(p).filter((f) => f.endsWith(".md"));
      return mds.length
        ? Math.max(...mds.map((f) => statSync(join(p, f)).mtimeMs))
        : statSync(p).mtimeMs;
    } catch {
      return 0;
    }
  };
  const ranked = candidates
    .map((p) => ({ p, m: newestTaskMtime(p) }))
    .sort((a, b) => b.m - a.m);
  return { folder: ranked[0].p, searched };
}

// ---------------------------------------------------------------------------
// Snapshot: full folder re-read + re-parse (files are small and few).
// ---------------------------------------------------------------------------

export function readSnapshot(folder, searched) {
  const snap = { folder, searched, tasks: [], generatedAt: new Date().toISOString() };
  if (!folder) return snap;
  let files;
  try {
    files = readdirSync(folder).filter((f) => f.endsWith(".md")).sort();
  } catch {
    return { ...snap, folder: null };
  }
  for (const file of files) {
    let text;
    try {
      text = readFileSync(join(folder, file), "utf8");
    } catch {
      continue; // transient: file deleted between readdir and read
    }
    let parsed;
    try {
      parsed = parseFrontmatter(text);
    } catch (err) {
      snap.tasks.push({ file, unparseable: true, error: String(err.message || err) });
      continue;
    }
    if (!parsed) continue; // no frontmatter → not a task card (000-feature.md)
    const { fm, body } = parsed;
    if (!fm.task) {
      snap.tasks.push({ file, unparseable: true, error: "missing task: field" });
      continue;
    }
    const titleMatch = body.match(/^# .*?—\s*(.+)$/m) || body.match(/^# (.+)$/m);
    const t = {
      file,
      id: fm.task,
      title: titleMatch ? titleMatch[1].trim() : fm.task,
      status: fm.status || "",
      kind: fm.kind || "technical",
      slice: typeof fm.slice === "string" ? fm.slice : "",
      phase: fm.phase || "",
      blockedOn: fm["blocked-on"] || "",
      reviewClean: fm.review === "clean",
      dependsOn: Array.isArray(fm.depends_on) ? fm.depends_on : fm.depends_on ? [fm.depends_on] : [],
      deviations: Array.isArray(fm.deviations) ? fm.deviations : [],
      recordYes: /^Record:\s*yes\s*$/m.test(body),
      goal: (body.split(/\r?\n/).find((l) => l.trim() && !l.startsWith("#")) || "").trim(),
    };
    const skill = computeAdvance(t);
    t.advance = skill ? { skill, prompt: `Run the /${skill} skill on task ${t.id}` } : null;
    t.column = t.kind === "technical" ? technicalColumn(t)
      : t.kind === "verify" ? verifyColumn(t) : null;
    snap.tasks.push(t);
  }
  return snap;
}
