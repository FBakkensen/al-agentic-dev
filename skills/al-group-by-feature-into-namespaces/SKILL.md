---
name: al-group-by-feature-into-namespaces
description: Use when an AL app has no namespaces, when a developer asks to organize an app's objects by feature into namespaces, or when the module gate is to be switched on in an existing repository.
---

# al-group-by-feature-into-namespaces - one app into feature namespaces

In: an AL app in a Consumer repository with its `al-build.json`. Out: every object in a feature namespace under `Naveksa.<Product>` with its folder and file name to match, and the module gate on. Every namespace comes out as open code: the skill creates no module and changes no object's access.

Every BC object, table, field, procedure, event, or enum value the map and its evidence name is confirmed by a lookup in the current session, never recalled. Write BC vocabulary: Post, Insert, Validate, Ledger Entry, codeunit, procedure.

## Survey

`<root>` is `Naveksa.<Product>`, the product named in its feature language from `app.json`.

▶ opus · survey the app in <app folder> into a namespace map under <root>: group by usage clusters (objects that reference each other, read and write the same fields, and serve one feature), named in the product's feature language and as granular as the code allows; an object spanning clusters lands at the namespace level covering everything it touches, unsplit; event publishers and procedures an add-on can call marked final → table of object type, ID, name, proposed namespace, folder, and evidence (what it references, what references it, which fields it shares), one row per object

## Agree

Show the map through `show_widget`, falling back to an Artifact, then a table in the reply, with the final objects first: their namespaces become public API once add-ons adopt them. Ask with `AskUserQuestion`: agree the map as shown (recommended), or name the namespaces to change; a change reruns the survey for the rows it touches. Nothing is written before the developer agrees. Done when the developer has agreed every row.

## Apply

Write the agreed map to `.output/namespace-map.json`: a JSON array with one entry per object, `{ "type", "id", "name", "namespace" }`, `type` the lower-case AL object keyword and `id` 0 for an object without one.

▶ haiku · /al-build provision the app's symbols, apply the namespace map `.output/namespace-map.json` with root namespace <root>, then the gate with ALBT_MODULE_GATE_ENABLED false and WARN_AS_ERROR as the repository states → apply exit code with every printed problem, summary.json verdict, per-runner totals, exact red cause

A failed apply writes nothing; a problem in the map goes back to the developer, and a failure partway through a write is restored with git first. The pass changes no behavior, so a red gate after it points at the map: stop with the exact red cause.

Each test app of the repository repeats Survey, Agree and Apply with root namespace `<root>.Test`, its objects in the namespaces mirroring the clusters their tests cover, applied with its own app folder.

## Switch the gate on

Once the gate is green, write `"moduleGate": { "enabled": true, "rootNamespace": "<root>" }` into `al-build.json`.

▶ haiku · /al-build gate with the module gate on, WARN_AS_ERROR as the repository states → summary.json verdict with its moduleGate block, per-runner totals, exact red cause

Done when the gate is green and `summary.json`'s `moduleGate` block shows enabled with zero violations. A violation names the file, the line, and the move; fix it and rerun.

## Close

At every exit — clean close, a red gate that pauses the run, or a question left with the developer:

▶ haiku · /al-commit the complete worktree → commit hashes and subjects, remaining worktree

Finish outcome first: the namespaces with their object counts, the final objects, the green gate with the module gate on, and the commits. Modules are carved from these clusters later, as the code is touched, through `/mattpocock-skills:improve-codebase-architecture`. Stop with the exact red reason when a gate does not pass.
