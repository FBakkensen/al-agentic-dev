# bc-code-intelligence dispatch

**The MCP recommends topics; the calling skill reviews.** `bc-code-intelligence` runs no server-side LLM inference: it pattern-matches AL constructs in the query or code against a topic store and returns a relevance-ranked list. A surfaced topic is a lead, never a finding. Choose the active reader's selection breadth under **Topic selection per reader**.

## Call pattern

1. **`set_workspace_info`** first, once per session: `workspace_root` (absolute) and `available_mcps` (the MCP ids in context). Returns `Loaded N topics from M layers`. Until it runs, every tool returns `⚠️ Server Not Yet Initialized`.

2. **`find_bc_knowledge`** per concern: `query` is BC-specific and names the construct or concern ("SetLoadFields placement before SetRange in a FindSet loop"), `search_type: "topics"`.

3. **Drop the noise** before any `get_bc_topic` call. Off-domain topics pattern-match common AL constructs (`SetRange`, `FindFirst`, `repeat`) and land as top-ranked false positives — rank is real; subject-match is not. The noise drop-list, discarded unconditionally:
   - `parker-pragmatic/*` — AI-collaboration methodology, scores ~100 on any AL code.
   - `*/recommend-*` — tool-upsell topics.
   - Off-domain topics whose subject does not match the concern (e.g. `taylor-docs/*` on a performance scan).

4. **`get_bc_topic`** for the on-domain survivors selected under **Topic selection per reader**, top-ranked first: `topic_id`, `include_samples: true`. The payload carries the rule markdown, correct/incorrect AL samples, `anti_pattern_indicators`, and a `finding_template`.

5. **Apply the rule yourself.** Match each `anti_pattern_indicator` against the diff. Where it matches, emit a finding in the topic's `finding_template` shape, citing the topic id. Where it does not, drop the topic.

   **AL false-positive guards.** An indicator matches syntax; three contexts exempt the match:
   - **The record is `temporary`** — in-memory, zero DB cost, so every access-pattern and partial-record perf topic (`SetLoadFields`, `FindSet` without filter, `Get` in loop) is moot.
   - **The field or object is `ObsoleteState = Pending`** with `ObsoleteReason` and `ObsoleteTag` and no upgrade code yet — the `Pending` → `Removed` window is the AppSource-safe deprecation path, not an unfinished defect.
   - **The topic recommends `ModifyAll`/`DeleteAll`** over a loop whose `OnModify`/`OnDelete` triggers run deliberately — the bulk call bypasses triggers and validation (default `RunTrigger=false`), so the swap silently drops that business logic. Flag the trigger-bypass risk instead of recommending the swap.

Run a vanilla pass on the same code, then dedupe overlapping findings.

Cache `get_bc_topic` responses within one invocation; call fresh across invocations.

## When to call it

Call the MCP for BC execution-order and platform-cost construct knowledge. Leave to the vanilla pass what it already catches: memoization, duplicate procedures, dead parameters. Exemplar: temporal coupling — BC executes `SetLoadFields → filter → query`, so `SetLoadFields` after `SetRange`/`SetFilter` is syntactically valid, the optimization is silently lost, and an unaided model reads it as fine — topic `dean-debug/setloadfields-placement-before-filters`.

## `analyze_al_code` — optional whole-file signal scan

For a code-matched topic scan without crafting a query, call `analyze_al_code` with `file_path` (absolute, singular) and `analysis_type`. Trust only `matched_signals` / `suggested_topics`: the same code-matched topics `find_bc_knowledge` returns, minus the query, so the same drop-list applies. Ignore `issues[]`; it is empirically empty on real defects. Ignore `optimization_opportunities[]`; it returns generic filler.

## Relevance scales and the backstop

The lever is the drop-list, not a cutoff. The entry tools report on incompatible scales, so no universal threshold exists:

| Tool | Score field | Scale |
|---|---|---|
| `find_bc_knowledge` | `relevance_score` | raw, unbounded (single digits → hundreds) |
| `analyze_al_code` | `relevance_score` | float `0.0–1.0` |

Once the noise is dropped, the genuinely relevant topics rank at the top natively. The backstop against a long tail is relative, per call: discard survivors scoring far below the same call's top cluster. Treat this relative backstop as a default, not a contract.

**MCP absent or init fails** → grounding stays satisfiable per `GROUND-RULES.md`: for constructs, quote a Microsoft Learn passage; for names, quote Microsoft Learn or use the `bc-standard-reference` agent. Degrade; never block on the missing server.

## Topic selection per reader

The call pattern is shared; selection breadth is not.

| Reader | Selection |
|---|---|
| `/al-implement` | Narrowest — write-time construct lookup: one query per construct class the task touches (the classes named in `GROUND-RULES.md`'s grounding rules), top on-domain survivor only, before first RED; topics cached for the rest of the task. |
| `/al-refactor` | Fewer — the structural anti-patterns to fix this pass. |
| `/al-code-review` | Widest — in-depth per-file consultation plus cross-file routing. |
| `al-researcher` (spawned by `/al-research`) | Whatever answers the framed question — the MCP is one of its source families. |

## Gaps the calling skill owns

Per-query topic dispatch is the entire contract.

| Gap | Ownership |
|---|---|
| **Cross-file analysis** — event publisher/subscriber signature mismatch, permission set vs new table field, and AppSource public-surface additions need multiple files read together | `/al-code-review` runs these as its own passes |
| **Diff-aware review** — it cold-scans whatever you pass | The calling skill scopes the diff |
| **Workflow orchestration / layer scaffolding** — the `workflow_*` and `*_layer_*` tools | Unused; the per-query dispatch gives the same signal |

## Upstream source

`JeremyVyska/bc-code-intelligence-mcp` (server) and `JeremyVyska/bc-code-intelligence` (knowledge). Advisory-grade: never make a deterministic gate depend on it alone. An empty topic list, or a payload missing its documented fields (`anti_pattern_indicators`, `finding_template`, `matched_signals`), warrants checking the source before concluding the tool is broken.
