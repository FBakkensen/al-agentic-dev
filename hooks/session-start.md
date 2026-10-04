# Delegation

- A `▶ <model> · <brief> → <return>` line is one `Agent` call with that `model`: `opus`, `sonnet`, or `haiku`.
- Every child runs in the lead's worktree and branch, never with `isolation: "worktree"`. Nothing limits how a child works, including delegating further.
- Fan-out is several background `Agent` calls in one message. Pick up each result from its completion notification; never poll.
- A child that needs a decision writes it out with options and a recommendation, then ends its turn. The lead asks the user through `AskUserQuestion` with those options and the recommendation unchanged, then relays the answer to the same child with `SendMessage`.
- Every dispatch prompt carries these fixed parts:
  - the brief;
  - the return contract;
  - the unattended line: `You run unattended; the user cannot answer mid-task. Proceed on every reversible step the work item already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.`;
  - "When a decision only the user can take blocks you, write the decision out and end your turn.";
  - the delegation-cost paragraph below, copied verbatim so it travels down the tree.

  A child that writes or judges AL also carries the grounding rule: every BC object, table, field, procedure, event, enum value, or dialog text it writes or judges is confirmed by a lookup in the current session, never recalled.
- A return that misses its contract, or a red twice on the same cause, is re-dispatched once, one step up `haiku` → `sonnet` → `opus`, with the child's output in the brief. A second miss, or a missed `opus` return, goes to the user with the evidence.

## Delegation cost

Spawn a child only for a sizeable, independent track of work whose result comes back compact. Work you can finish in a handful of tool calls, you do yourself. Keep spawn counts low. A skill's `▶` line is already that judgement: run it as written.

## Entry skills and their AL additions

In an AL repository, when an entry skill below runs, load its AL addition beside it with the `Skill` tool. The addition adds only what is AL-specific; the entry skill owns the process.

| Entry skill | AL addition |
|---|---|
| `/mattpocock-skills:setup-matt-pocock-skills` | `/al-setup-matt-pocock-skills` |
| `/mattpocock-skills:grill-with-docs` | `/al-grill-with-docs` |
| `/mattpocock-skills:to-spec` | `/al-to-spec` |
| `/mattpocock-skills:to-tickets` | `/al-to-tickets` |
| `/mattpocock-skills:implement` | `/al-implement` |
| `/mattpocock-skills:tdd` | `/al-tdd` |
| `/mattpocock-skills:codebase-design` | `/al-codebase-design` |
| `/mattpocock-skills:code-review` | `/al-review` |
| `/simplify` | `/al-simplify` |
| `/mattpocock-skills:improve-codebase-architecture` | `/al-improve-codebase-architecture` |
| `/mattpocock-skills:diagnosing-bugs` | `/al-diagnosing-bugs` |
| `/mattpocock-skills:wayfinder` | `/al-wayfinder` |
| `/mattpocock-skills:prototype` | `/al-prototype` |
| `/mattpocock-skills:research` | `/al-research` |

## Reading an AL path

In an AL repository whose `al-build.json` has `moduleGate.enabled` true, the path of code says how to treat it:

- A folder named `Internal` holds a module's internals: call them only from inside that module.
- A folder with an `Internal` child is a module's interface: call the module from anywhere, through that folder.
- Any other folder is open code: a fix inside an existing procedure stays there; a new object, callable procedure, or event subscriber goes into a module, carved as a child namespace with its own `Internal`.
