---
name: al-clone-bcquality
description: Clone Microsoft's BCQuality knowledge base into .bcquality/ and build its knowledge index, so the review leaves and the design chain work from BC-specific rules rather than recall. The provision task's third step, and runnable anytime to refresh the clone.
disable-model-invocation: true
---

# /al-clone-bcquality — the BC quality knowledge base

Symbols say a name exists and `.bcapps/` shows how Microsoft builds it; BCQuality says
what a model reviewing or writing AL gets wrong unaided — atomic rules admitted only
because their absence produces a mistake, one review skill per knowledge domain. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Precondition

None beyond the workspace. Run it as the provision task's third step when routed
there, or ad hoc whenever `.bcquality/` is missing, suspect, or due a refresh.
Task-file state is `/al-routing`'s.

## Target

- **Source** — `https://github.com/microsoft/BCQuality`, branch `main`. The knowledge base is
  additive content rather than code bound to a runtime, so nothing pins to the app's BC
  version and every run lands on the upstream head.
- **Layers** — all three: `microsoft/` endorsed, `community/`, and `custom/`, empty
  upstream. Which layer wins when two contradict is BCQuality's own rule.
- **Skills** — `skills/` carries the entry point and the READ · DO · WRITE contracts,
  `microsoft/skills/review/` the review leaves the pipeline runs.

## Run

Upstream revises and retires articles continuously, so every run refreshes — a clone
left at provision day drifts, and a stale article is indistinguishable from a current
one. A missing or broken clone takes the first line below; a healthy one takes the next
two, resetting rather than merging so an article deleted or renamed upstream leaves the
tree instead of lingering for a consumer to cite. The last line always runs, because
the index is generated and otherwise describes the tree that was there before.

```
git clone --depth 1 --single-branch --branch main https://github.com/microsoft/BCQuality .bcquality
git -C .bcquality fetch --depth 1 origin main
git -C .bcquality reset --hard FETCH_HEAD
pwsh .bcquality/tools/Build-KnowledgeIndex.ps1
```

The generator writes `.bcquality/knowledge-index.json`, one row per article carrying
the path, layer, domain, frontmatter dimensions and keywords a consumer selects on —
discovery acceleration, not content. Every consumer selects on that index, so an index
that would not build is a red run like any other.

The repo's `.gitignore` carries a `.bcquality/` line — add it when missing, committing the edit with a plain descriptive message.

Green when the tree sits on the head fetched this run, `.bcquality/microsoft/knowledge/`
holds articles, `.bcquality/microsoft/skills/review/al-code-review.md` is present with
the review leaves it lists, and the index carries a row for every article under a
`knowledge/` folder on disk.

## Close

Name the outcome — the clone on disk at the upstream head with its index, or one line
naming what failed in the terms the developer acts on. Clearing a red is the
developer's move; re-run this skill afterwards.

Ran as the provision task's step → then `/al-routing`. Ran ad hoc → close back into the
work that needed the clone; nothing to route.
