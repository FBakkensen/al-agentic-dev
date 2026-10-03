# GitHub procedure for al-pull-request

Hosts: `github.com`.

## Read the existing pull request

`<owner>/<name>` comes from the `origin` URL, passed to every `gh` call as `--repo`. List the branch's open pull request: `gh pr list --repo <owner>/<name> --head <branch> --state open --json number,url,isDraft,closingIssuesReferences,body`. Its linked work items on a GitHub Tracker are the issues in `closingIssuesReferences`, which lists them only for a pull request into the default branch; for any other base, they are the `Fixes #<n>` lines of `body`. On an Azure DevOps Tracker they are the `AB#<id>` lines of `body`.

## Description cap

GitHub caps the body at 65,536 characters.

## Create or update

Write the body to a file with the Write tool. With no pull request, create a ready one: `gh pr create --repo <owner>/<name> --base <base> --head <branch> --title <title> --body-file <file>`. With one, call `gh pr edit <n> --repo <owner>/<name> --title <title> --body-file <file>`, then `gh pr ready <n> --repo <owner>/<name>` when `isDraft` is true.
