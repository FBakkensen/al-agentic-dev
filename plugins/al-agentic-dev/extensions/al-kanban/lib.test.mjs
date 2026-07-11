// node:test suite for the al-kanban pure logic (lib.mjs). Zero dependencies:
// run with `node --test lib.test.mjs`. Server/SSE/watcher/canvas lifecycle are
// deliberately out of scope — SMOKE-TEST.md owns those.

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, utimesSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execFileSync } from "node:child_process";
import { parseFrontmatter, computeAdvance, discoverTasksFolder } from "./lib.mjs";

// ---------------------------------------------------------------------------
// 1. Frontmatter parser
// ---------------------------------------------------------------------------

const fence = (inner, body = "# T-001 — Title\n\nGoal line.") =>
  `---\n${inner}\n---\n${body}`;

test("parser: flat scalars", () => {
  const { fm, body } = parseFrontmatter(fence("task: T-001\nstatus: ready\nslice: my-slice\nkind: technical"));
  assert.deepEqual(fm, { task: "T-001", status: "ready", slice: "my-slice", kind: "technical" });
  assert.match(body, /^# T-001/m);
});

test("parser: inline lists", () => {
  const { fm } = parseFrontmatter(fence("task: T-003\ndepends_on: [T-001, T-002]\nrefactors: []"));
  assert.deepEqual(fm.depends_on, ["T-001", "T-002"]);
  assert.deepEqual(fm.refactors, []);
});

test("parser: block list of strings", () => {
  const { fm } = parseFrontmatter(fence(
    "task: T-004\ndeviations:\n- assumed posting date is workdate\n- used default dimension set",
  ));
  assert.deepEqual(fm.deviations, [
    "assumed posting date is workdate",
    "used default dimension set",
  ]);
});

test("parser: unknown fields pass through untouched", () => {
  const { fm } = parseFrontmatter(fence("task: T-005\nfuture-field: some value\nother_list: [a, b]"));
  assert.equal(fm["future-field"], "some value");
  assert.deepEqual(fm.other_list, ["a", "b"]);
});

test("parser: unclosed inline list throws", () => {
  assert.throws(() => parseFrontmatter(fence("task: T-018\ndepends_on: [T-001, T-002")), /unclosed inline list/);
});

test("parser: empty value with no block list throws", () => {
  assert.throws(() => parseFrontmatter(fence("task: T-006\ndeviations:")), /empty value/);
});

test("parser: line without colon throws", () => {
  assert.throws(() => parseFrontmatter(fence("task: T-007\nnot a field line")), /bad frontmatter line/);
});

test("parser: frontmatter never closed throws", () => {
  assert.throws(() => parseFrontmatter("---\ntask: T-008\n# no closing fence"), /never closed/);
});

test("parser: no frontmatter returns null (000-feature.md case)", () => {
  assert.equal(parseFrontmatter("# Feature — Item charge validation\n\nGoal prose."), null);
});

test("parser: CRLF line endings", () => {
  const { fm } = parseFrontmatter("---\r\ntask: T-009\r\nstatus: done\r\n---\r\n# T-009 — X\r\n");
  assert.equal(fm.task, "T-009");
  assert.equal(fm.status, "done");
});

// ---------------------------------------------------------------------------
// 2. Advance mapping — the full (kind, status, phase) table
// ---------------------------------------------------------------------------

const adv = (kind, status, phase = "", extra = {}) =>
  computeAdvance({ kind, status, phase, reviewClean: false, recordYes: false, ...extra });

test("advance: technical pipeline", () => {
  assert.equal(adv("technical", "ready"), "al-refine");
  assert.equal(adv("technical", "ready-for-implementation", "refined"), "al-implement");
  assert.equal(adv("technical", "done", "implemented"), "al-refactor");
  assert.equal(adv("technical", "done", "refactored"), "al-mutate");
});

test("advance: technical no-button states", () => {
  assert.equal(adv("technical", "done", "mutated"), null); // pipeline exhausted
  assert.equal(adv("technical", "blocked"), null);
  assert.equal(adv("technical", "blocked", "refined"), null); // phase survives block, no button
  assert.equal(adv("technical", "ready", "refined"), null); // inconsistent state → no button
  assert.equal(adv("technical", "ready-for-implementation"), null); // stamp missing
});

test("advance: verify pipeline", () => {
  assert.equal(adv("verify", "ready", "", { reviewClean: true }), "al-refine");
  assert.equal(adv("verify", "ready-for-verification", "planned", { recordYes: true }), "al-page-script");
  assert.equal(adv("verify", "ready-for-verification", "planned", { recordYes: false }), "al-user-verification");
  assert.equal(adv("verify", "ready-for-verification", "page-scripted"), "al-user-verification");
});

test("advance: verify no-button states", () => {
  assert.equal(adv("verify", "ready"), null); // no review: clean → still waiting
  assert.equal(adv("verify", "blocked"), null); // waiting on gate
  assert.equal(adv("verify", "done", "page-scripted"), null); // verified
  assert.equal(adv("verify", "ready", "planned", { reviewClean: true }), null); // stale phase
});

test("advance: ops kinds", () => {
  assert.equal(adv("provision", "ready"), "al-provision");
  assert.equal(adv("provision", "done"), null);
  assert.equal(adv("breaking-change", "ready"), "al-validate-breaking-changes");
  assert.equal(adv("breaking-change", "blocked"), null);
});

// ---------------------------------------------------------------------------
// 3. Folder discovery — temp dirs, cleaned up per test
// ---------------------------------------------------------------------------

function tempRoot(t) {
  const dir = mkdtempSync(join(tmpdir(), "al-kanban-test-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function makeSpec(root, name, taskFiles = ["010-T-001-x.md"]) {
  const tasks = join(root, "specs", name, "tasks");
  mkdirSync(tasks, { recursive: true });
  for (const f of taskFiles) writeFileSync(join(tasks, f), "---\ntask: T-001\nstatus: ready\n---\n# t\n");
  return tasks;
}

test("discovery: explicit input folder wins, relative to working directory", (t) => {
  const root = tempRoot(t);
  const tasks = makeSpec(root, "100-explicit");
  const r = discoverTasksFolder(root, join("specs", "100-explicit", "tasks"));
  assert.equal(r.folder, tasks);
});

test("discovery: explicit input that does not exist → null, path named in searched", (t) => {
  const root = tempRoot(t);
  const r = discoverTasksFolder(root, "specs\\999-missing\\tasks");
  assert.equal(r.folder, null);
  assert.equal(r.searched.length, 1);
  assert.match(r.searched[0], /999-missing/);
});

test("discovery: git branch containing the spec slug wins over mtime", (t) => {
  const root = tempRoot(t);
  const target = makeSpec(root, "100-charge-validation");
  const decoy = makeSpec(root, "200-other-feature");
  // decoy is the newer folder — branch match must still win
  const future = new Date(Date.now() + 60_000);
  utimesSync(join(decoy, "010-T-001-x.md"), future, future);
  execFileSync("git", ["init", "-q", "-b", "flemming-charge-validation-work"], { cwd: root });
  const r = discoverTasksFolder(root, undefined);
  assert.equal(r.folder, target);
});

test("discovery: no branch match → most recently modified task file wins", (t) => {
  const root = tempRoot(t); // not a git repo → gitBranch() = ""
  makeSpec(root, "100-older");
  const newer = makeSpec(root, "200-newer");
  const future = new Date(Date.now() + 60_000);
  utimesSync(join(newer, "010-T-001-x.md"), future, future);
  const r = discoverTasksFolder(root, undefined);
  assert.equal(r.folder, newer);
});

test("discovery: no specs dir → empty state naming the searched glob", (t) => {
  const root = tempRoot(t);
  const r = discoverTasksFolder(root, undefined);
  assert.equal(r.folder, null);
  assert.match(r.searched[0], /specs/);
  assert.match(r.searched[0], /tasks/);
});

test("discovery: specs dir with no tasks subfolders → empty state", (t) => {
  const root = tempRoot(t);
  mkdirSync(join(root, "specs", "100-no-tasks-here"), { recursive: true });
  const r = discoverTasksFolder(root, undefined);
  assert.equal(r.folder, null);
});
