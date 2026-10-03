# GitHub procedure for al-pull-request

Hosts: `github.com`.

## Read the existing pull request

`<owner>/<name>` comes from the `origin` URL, passed to every `gh` call as `--repo`. List the branch's open pull request: `gh pr list --repo <owner>/<name> --head <branch> --state open --json number,url,isDraft,closingIssuesReferences,body`. Its linked work items are the ones the tracker text's "How a pull request names a work item" says a GitHub pull request names, read from `body`. On a GitHub Tracker, `closingIssuesReferences` lists the closing issues only for a pull request into the default branch; for any other base, read the `Fixes #<n>` lines of `body`.

## Description cap

GitHub caps the body at 65,536 characters.

## Create or update

Write the body to a file with the Write tool. With no pull request, create a ready one: `gh pr create --repo <owner>/<name> --base <base> --head <branch> --title <title> --body-file <file>`. With one, call `gh pr edit <n> --repo <owner>/<name> --title <title> --body-file <file>`, then `gh pr ready <n> --repo <owner>/<name>` when `isDraft` is true.
