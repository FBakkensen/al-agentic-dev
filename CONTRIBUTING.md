# Contributing to al-agentic-dev

Thank you for your interest in contributing to this Claude Code plugin of Agent Skills for AL/Business Central development.

## Reporting issues

- Use GitHub Issues to report bugs or suggest features, with the bug report or feature request template.
- Search existing issues before creating a new one.
- Give clear steps to reproduce a bug, and your environment (OS, PowerShell version, Claude Code version).

## The rulebook

The rules this repository enforces live in two places. Read them before you change anything:

- [`CLAUDE.md`](CLAUDE.md) — what ships, what never ships, the branch and PR process, and the trigger evals.
- [`.claude/rules/`](.claude/rules/) — `skills.md` is the skill authoring contract; `powershell.md` is the PowerShell contract.

## Pull requests

`main` is PR-only. A change lands on a feature branch and merges through a pull request; nothing is pushed to `main` directly.

- **Maintainers** branch from `main`, push the feature branch, and open a PR against `main`.
- **Outside contributors** fork the repository, branch in the fork, push there, and open a PR from the fork against `main`.

1. Branch from an up-to-date `main` (`git checkout -b feature/my-feature`).
2. Make your change. Keep it to one purpose per PR.
3. Run the CI checks below and the evals your change calls for.
4. Commit with a clear message that says why. Recent history prefixes the type (`fix:`, `docs:`, `chore:`); follow it, and reference the issue number when there is one.
5. Open the PR. The template asks which skills it touches and what you tested. Name the issue it closes with `Fixes #<n>`.

The plugin version lives only in `.claude-plugin/plugin.json`; leave it to the maintainer unless the issue says otherwise.

## CI checks

Every PR and every push to `main` runs the same five checks from `.github/workflows/ci.yml`. Run them from the repository root in PowerShell 7.2+ before you push:

| Check | Local command |
| --- | --- |
| JSON | `./scripts/Validate-Json.ps1` |
| PowerShell | `./scripts/Validate-PowerShell.ps1` |
| Skills | `./scripts/Validate-Skills.ps1` |
| Base plugin drift | `./scripts/Test-BasePluginDrift.ps1` |
| Pester | `./scripts/Invoke-Tests.ps1 -Mode Full` |

`Validate-Skills.ps1` and the Pester run need the `powershell-yaml` module (`Install-Module powershell-yaml -Scope CurrentUser`); the Pester run also needs Pester 5 or later. For a faster local loop, `./scripts/Invoke-Tests.ps1 -Mode Fast` skips the process-bound and live-fixture tests, but the PR must pass `-Mode Full`.

Every PR also runs the required `claude-review` check, a Claude review of the change. It posts each blocking finding as a review thread and fails while one stands. `main` merges only when every check passes and every review thread is resolved: fix the finding, or reply on the thread with why it is wrong. GitHub withholds repository secrets from fork PRs, so a maintainer may have to run `claude-review` for yours.

## Skill development

A skill is a folder under `skills/` with a `SKILL.md`, installed on its own:

```
skills/skill-name/
├── SKILL.md          # frontmatter: name, description
├── SOME-FORMAT.md    # optional sibling files, referenced relatively
└── scripts/          # al-build only
```

- The folder name equals the frontmatter `name`, and the frontmatter has only `name` and `description`.
- Keep every relative link inside the skill folder.
- Outside `skills/al-build/`, a skill never names a `.ps1` file or a `scripts/` path; it calls `/al-build` instead.
- Read [`.claude/rules/skills.md`](.claude/rules/skills.md) before you write; it is the full authoring contract, and `Validate-Skills.ps1` enforces much of it.

### Trigger evals

A new skill, or a change to a skill's `description` or its triggers, ships with its trigger eval case under `evals/<case>/`: a `prompt.md` and a `graders/` folder. An eval checks only that the skill fires; it never grades the skill's output. `tests/EvalSuite.Tests.ps1` fails when a skill has no case.

Run your case before you open the PR, three runs, passing at two of three. Evals are billed runs, so CI never runs them and you run only the case you touched. [`CLAUDE.md`](CLAUDE.md) under "Trigger evals" has the commands, the Base plugin copies they load, and how to seed a repository for an AL addition. A change that touches no description or trigger needs no eval.

## PowerShell

Test PowerShell scripts on PowerShell 7.2+. The PowerShell substrate ships only under `skills/al-build/` and `hooks/`; follow [`.claude/rules/powershell.md`](.claude/rules/powershell.md).
