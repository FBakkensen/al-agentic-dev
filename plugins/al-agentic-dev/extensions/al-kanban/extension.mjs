// al-kanban — GitHub Copilot canvas extension for the al-agentic-dev plugin.
// Renders the specs/<NNN>-<slug>/tasks/ pipeline as a live kanban board.
// Read-only over task files: skills remain the only writers.
// Pure logic (parser, advance mapping, discovery, snapshot) lives in lib.mjs
// so it also loads under plain `node --test` without the SDK host.

import { createServer } from "node:http";
import { readFileSync, watch } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { joinSession, createCanvas } from "@github/copilot-sdk/extension";
import { discoverTasksFolder, readSnapshot } from "./lib.mjs";

const EXT_DIR = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Per-instance server + watcher.
// ---------------------------------------------------------------------------

const instances = new Map();

function startInstance(instanceId, workingDirectory, input, session) {
  const { folder, searched } = discoverTasksFolder(workingDirectory, input?.tasksFolder);
  const sseClients = new Set();
  const state = { folder, searched, server: null, watcher: null, sseClients };

  const broadcast = () => {
    const data = JSON.stringify(readSnapshot(state.folder, state.searched));
    for (const res of sseClients) res.write(`event: update\ndata: ${data}\n\n`);
  };

  if (folder) {
    let timer = null;
    try {
      state.watcher = watch(folder, { persistent: false }, () => {
        clearTimeout(timer);
        timer = setTimeout(broadcast, 200); // debounce Windows duplicate/rename events
      });
    } catch (err) {
      session.log(`al-kanban: watcher failed for ${folder}: ${err}`);
    }
  }

  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname === "/") {
      res.setHeader("Content-Type", "text/html; charset=utf-8");
      res.end(readFileSync(join(EXT_DIR, "board.html"), "utf8"));
    } else if (url.pathname === "/data") {
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify(readSnapshot(state.folder, state.searched)));
    } else if (url.pathname === "/events") {
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      });
      res.write(": connected\n\n");
      sseClients.add(res);
      req.on("close", () => sseClients.delete(res));
    } else if (url.pathname === "/advance" && req.method === "POST") {
      let bodyText = "";
      req.on("data", (c) => (bodyText += c));
      req.on("end", async () => {
        try {
          // Client sends only the task id; the prompt is recomputed server-side
          // from current frontmatter so the board can never inject prompt text.
          const { task } = JSON.parse(bodyText);
          if (typeof task !== "string" || !/^T-\d{3}$/.test(task)) {
            throw new Error("advance expects { task: \"T-NNN\" }");
          }
          const snap = readSnapshot(state.folder, state.searched);
          const t = snap.tasks.find((x) => x.id === task && !x.unparseable);
          if (!t?.advance) throw new Error(`no advance available for ${task}`);
          await session.send({ prompt: t.advance.prompt });
          res.setHeader("Content-Type", "application/json");
          res.end(JSON.stringify({ ok: true, prompt: t.advance.prompt }));
        } catch (err) {
          res.statusCode = 400;
          res.end(JSON.stringify({ ok: false, error: String(err.message || err) }));
        }
      });
    } else {
      res.statusCode = 404;
      res.end("not found");
    }
  });

  return new Promise((resolvePromise) => {
    server.listen(0, "127.0.0.1", () => {
      state.server = server;
      state.url = `http://127.0.0.1:${server.address().port}/`;
      instances.set(instanceId, state);
      resolvePromise(state.url);
    });
  });
}

// Concurrent open() calls for the same instance share one start promise so a
// race can never spin up a second orphaned server/watcher.
const starting = new Map();

async function stopInstance(instanceId) {
  const state = instances.get(instanceId);
  if (!state) return;
  instances.delete(instanceId);
  state.watcher?.close();
  for (const res of state.sseClients) res.end();
  state.sseClients.clear();
  await new Promise((r) => (state.server ? state.server.close(() => r()) : r()));
}

// ---------------------------------------------------------------------------
// Canvas registration.
// ---------------------------------------------------------------------------

const session = await joinSession({
  canvases: [
    createCanvas({
      id: "al-kanban",
      displayName: "AL Kanban",
      description:
        "Live kanban board over the al-agentic-dev task pipeline (specs/<NNN>-<slug>/tasks/). Read-only; Advance sends the next skill command into the chat.",
      inputSchema: {
        type: "object",
        properties: {
          tasksFolder: {
            type: "string",
            description:
              "Optional explicit tasks folder (absolute, or relative to the session working directory). Omit to auto-discover specs/*/tasks by git branch, then by most recent.",
          },
        },
      },
      open: async (ctx) => {
        const entry = instances.get(ctx.instanceId);
        if (entry) return { title: "AL Kanban", url: entry.url };
        let pending = starting.get(ctx.instanceId);
        if (!pending) {
          pending = startInstance(
            ctx.instanceId,
            ctx.session.workingDirectory,
            ctx.input,
            session,
          ).finally(() => starting.delete(ctx.instanceId));
          starting.set(ctx.instanceId, pending);
        }
        return { title: "AL Kanban", url: await pending };
      },
      onClose: async (ctx) => {
        await stopInstance(ctx.instanceId);
      },
    }),
  ],
});
