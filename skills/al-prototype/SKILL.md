---
name: al-prototype
description: Use whenever /mattpocock-skills:prototype runs in an AL repository, a folder that holds an app.json and .al source, to give its throwaway prototype an AL app, its own branch, and its own container.
---

# al-prototype - a throwaway AL app with its own container

In: `/mattpocock-skills:prototype` in an AL repository. The entry skill owns its rules and the question; this addition supplies the AL artifact forms, and its click-through HTML file is none of them. The session is live: the user answers questions and agrees to a container form.

## Home

The agent puts the app on its own `prototype/<name>` branch of the repository, named so a reader sees it is a prototype, and makes it depend on the main app.
- The agent lists the app in the branch's `al-build.json` under `testApps`, or under `containerTestApps` when the form needs it; that edit lives on the prototype branch only.
- The branch gets its own branch-named agent container through /al-build.

Done when the branch holds the app and /al-build has built it.

## Gate

The app carries its own `.vscode/settings.json` with no analyzers: /al-build reads the app's own settings before the repository's, and an empty file requests none. The zero-warnings bar does not apply; the evidence is the verdict.

## Forms

The question picks the form, and /al-build owns how each one runs.
1. **Logic through AL Runner.** The default. The agent writes test codeunits that push the state model through the cases hard to reason about on paper, each asserting the full relevant state after every action so a red names what differed. Done when `summary.json` shows each case's result.
2. **Logic that needs a surface AL Runner refuses** (`RunnerOutOfScopeException`). The agent moves the app to `containerTestApps` and runs container tests, only after the user agrees in the live session. Done when the container run shows each case's result.
3. **UI or UX, on top of either.** The agent republishes the app into the prototype's container through /al-build, whose output carries the `.test` URL and login; the container login is not a secret (/al-build), and the user sees both during the walk. Before the first browser call the agent invokes /al-webclient and drives each variant through it, in the first available browser driver. Done when every variant has one screenshot at `.output/prototype/<name>/<variant>.png`.

## Grounding

The agent confirms every BC object, table, field, procedure, event, enum value, and dialog text the prototype writes, shows, or judges by a lookup in this session, never from recall, and writes every line in Business Central vocabulary.

## Close

The agent runs /al-commit at every exit, then in order:
1. It pushes `prototype/<name>` and keeps it as the primary source; the prototype branch is never merged.
2. It attaches the screenshots in-line as the Tracker doc's "attach a file" says; with no UI form, nothing is attached.
3. It posts one comment as the Tracker doc's "comment" says: the verdict, the branch pointer, and the screenshots.
4. /al-build removes the prototype's agent container by name while the branch still exists.

A pause for the user's answer in the live session keeps the container; a stop that ends the prototype without a verdict still commits, pushes, and removes it.

Done when the branch is on the remote, every screenshot is a verified attachment, the comment is posted, and the container is gone. The reply names the verdict, the branch, and the screenshots back to the `/mattpocock-skills:prototype` run.
