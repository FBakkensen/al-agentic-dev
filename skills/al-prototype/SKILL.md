---
name: al-prototype
description: Use whenever /mattpocock-skills:prototype runs in an AL repository, a folder that holds an app.json and .al source, to give its throwaway prototype an AL app, its own branch, and its own container.
---

# al-prototype - a throwaway AL app with its own container

In: `/mattpocock-skills:prototype` in an AL repository. The entry skill owns its rules and the question; this addition supplies the AL artifact forms, and its click-through HTML file is none of them. The session is live: the user answers questions and agrees to a container form.

## Home

The app lives on its own `prototype/<name>` branch of the repository, depends on the main app, and is named so a reader sees it is a prototype.
- The branch's `al-build.json` lists the app under `testApps`, or under `containerTestApps` when the form needs it; that edit lives on the prototype branch only.
- The branch gets its own branch-named agent container through /al-build.

## Gate

The app carries its own `.vscode/settings.json` with no analyzers: /al-build reads the app's own settings before the repository's, and an empty file requests none. The zero-warnings bar does not apply; the evidence is the verdict.

## Forms

The question picks the form, and /al-build owns how each one runs.
1. **Logic through AL Runner.** The default. The app's test codeunits push the state model through the cases hard to reason about on paper, each asserting the full relevant state after every action so a red names what differed. Done when `summary.json` shows each case's result.
2. **Logic that needs a surface AL Runner refuses** (`RunnerOutOfScopeException`). The app moves to `containerTestApps` and runs as container tests, only after the user agrees in the live session. Done when the container run shows each case's result.
3. **UI or UX, on top of either.** /al-build republishes the app into the prototype's container, and its output carries the `.test` URL and login; the container login is not a secret (/al-build), and the user sees both during the walk. Before the first browser call the agent invokes /al-webclient and drives each variant through it, in the driver /al-walkthrough picks. Done when every variant has one screenshot, saved as `.output/prototype/<name>/<variant>.png` as /al-walkthrough's Evidence step saves one.

## Grounding

The agent confirms every BC object, table, field, procedure, event, enum value, and dialog text the prototype writes, shows, or judges by a lookup in this session, never from recall, and writes every line in Business Central vocabulary.

## Close

1. The agent attaches the screenshots in-line as the Tracker doc's "attach a file" says, then posts one comment as the Tracker doc's "comment" says: the verdict, the branch pointer, and the screenshots. With no UI form, nothing is attached.
2. The agent runs /al-commit, pushes `prototype/<name>`, and keeps it as the primary source; the prototype branch is never merged.
3. /al-build removes the prototype's agent container by name while the branch still exists.

Done when the comment is posted, the branch is on the remote, and the container is gone. The agent runs /al-commit at every exit, and the reply names the verdict, the branch, and the screenshots back to the `/mattpocock-skills:prototype` run.
