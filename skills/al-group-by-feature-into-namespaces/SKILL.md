---
name: al-group-by-feature-into-namespaces
description: Use when an AL app has no namespaces, when a developer asks to organize an app's objects by feature into namespaces, or when the module gate is to be switched on in an existing repository.
---

# al-group-by-feature-into-namespaces - an app and its test apps into feature namespaces

In: an AL app in a Consumer repository with its `al-build.json`. Out: every object of the app and of every test app (`containerTestApps` included) in a feature namespace with its folder and file name to match, and the module gate on. Every namespace comes out as open code: the skill creates no module and changes no object's access.

Every BC object, table, field, procedure, event, or enum value the map and its evidence name is confirmed by a lookup in the current session, never recalled. Write BC vocabulary: Post, Insert, Validate, Ledger Entry, codeunit, procedure.

## Survey

`<root>` is `Naveksa.<Product>`, proposed from the `app.json` name and agreed with the map. One survey covers the app and every test app.

▶ opus · survey the app in <app folder> and the test apps <test app folders> into one namespace map: group by usage clusters (objects that reference each other, read and write the same fields, and serve one feature) under <root>, named in the product's feature language and as granular as the code allows; an object spanning clusters lands at the namespace level covering everything it touches, unsplit; event publishers and procedures an add-on can call marked final; a test object lands in <root>.Test plus the namespace path of the objects it exercises, at the covering level when it spans clusters → table of object type, ID, name, proposed namespace, folder (the namespace path below the source root), and evidence (what it references, what references it, which fields it shares), one row per object

## Agree

Show the map through `show_widget`, falling back to an Artifact, then a table in the reply, with the final objects first: their namespaces become public API once add-ons adopt them. Ask with `AskUserQuestion`: agree the map as shown (recommended), or name the namespaces to change. Nothing is written before the developer agrees. Done when the developer has agreed every row.

## Apply

Split the agreed map into one file per app, `.output/namespace-map.json` for the app and `.output/namespace-map-<app folder>.json` for each test app: a JSON array with one entry per object of that app, `{ "type", "id", "name", "namespace" }`, `type` the lower-case AL object keyword and `id` 0 for an object without one.

▶ haiku · /al-build provision the symbols, apply `.output/namespace-map.json` with root namespace <root>, then the gate with ALBT_MODULE_GATE_ENABLED false and WARN_AS_ERROR as the repository states → apply exit code with every printed problem, summary.json verdict, per-runner totals, exact red cause

Each test app follows once that gate is green, because the gate leaves the app's symbols in each test app's cache and a new provision would clear them:

▶ haiku · /al-build apply each test app's map `.output/namespace-map-<app folder>.json` with root namespace <root>.Test and that app folder, without provisioning, then the gate with ALBT_MODULE_GATE_ENABLED false and WARN_AS_ERROR as the repository states → apply exit code per test app with every printed problem, summary.json verdict, per-runner totals, exact red cause

A failed apply writes nothing; the lead takes a problem in the map back to the developer and restores the tree with git after a failure partway through a write. The pass changes no behavior, so a red gate points at the map. Done when both gates are green.

## Switch the gate on

Once both gates are green, the lead writes `"moduleGate": { "enabled": true, "rootNamespace": "<root>" }` into `al-build.json`.

▶ haiku · /al-build gate with the module gate on, WARN_AS_ERROR as the repository states → summary.json verdict with its moduleGate block, per-runner totals, exact red cause

Done when the gate is green and `summary.json`'s `moduleGate` block shows enabled with zero violations. A violation names the file, the line, and the move; the lead fixes it and reruns.

## Close

At every exit — clean close, a red gate that pauses the run, or a question left with the developer:

▶ haiku · /al-commit the complete worktree → commit hashes and subjects, remaining worktree

Finish outcome first: the namespaces with their object counts, the final objects, the green gate with the module gate on, and the commits. Modules are carved from these clusters later, as the code is touched, through `/mattpocock-skills:improve-codebase-architecture`. Stop with the exact red reason when a gate does not pass.
