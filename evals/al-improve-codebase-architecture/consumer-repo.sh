#!/usr/bin/env bash
# Seeds an AL Consumer repository with a one-line change in the working tree:
# the committed app and tracker text, then an uncommitted field, so
# /mattpocock-skills:improve-codebase-architecture runs in an AL repository
# with a work tree that is not clean and the addition has a repository to read.
# The seed is deliberately free of work items: the entry runs with none named.
set -euo pipefail

mkdir -p src docs/agents

cat > app.json <<'JSON'
{
  "id": "5b6f3c2e-8d41-4a7e-9c0b-2f1e7d9a4b10",
  "name": "ShopFloor",
  "publisher": "Naveksa",
  "version": "1.0.0.0",
  "platform": "26.0.0.0",
  "application": "26.0.0.0",
  "runtime": "15.0",
  "idRanges": [{ "from": 50100, "to": 50199 }]
}
JSON

cat > src/ShopFloorSetup.Table.al <<'AL'
table 50100 "ShopFloor Setup"
{
    fields
    {
        field(1; "Primary Key"; Code[10]) { }
    }
}
AL

cat > CLAUDE.md <<'MD'
## Agent skills

### Issue tracker

Azure DevOps work items in org `naveksaas`; new Original work items go into the `NAVEKSA NEXT` project. See `docs/agents/issue-tracker.md`.
MD

cat > docs/agents/issue-tracker.md <<'MD'
# Issue tracker: Azure DevOps

Work items for this repository live in the Azure DevOps org `naveksaas`, read and written through the bundled `ado` MCP server's tools. The Original work item is the Feature, Bug, or PBI the request arrives on; several slices each get one direct child PBI under it.
MD

git init -q
git -c core.autocrlf=false add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "ShopFloor app"

cat > src/ShopFloorSetup.Table.al <<'AL'
table 50100 "ShopFloor Setup"
{
    fields
    {
        field(1; "Primary Key"; Code[10]) { }
        field(2; "Default Location Code"; Code[10]) { }
    }
}
AL
