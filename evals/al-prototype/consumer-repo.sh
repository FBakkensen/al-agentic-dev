#!/usr/bin/env bash
# Seeds an AL Consumer repository that /mattpocock-skills:setup-matt-pocock-skills
# already pointed at Azure DevOps: an app, its source, and the tracker text.
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
        field(10; "Default Location Code"; Code[10])
        {
            TableRelation = Location;
        }
    }
}
AL

cat > src/ShopFloorSalesDefaults.Codeunit.al <<'AL'
codeunit 50100 "ShopFloor Sales Defaults"
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", OnAfterInsertEvent, '', false, false)]
    local procedure SetDefaultLocation(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    var
        ShopFloorSetup: Record "ShopFloor Setup";
    begin
        if not ShopFloorSetup.Get() then
            exit;
        Rec."Location Code" := ShopFloorSetup."Default Location Code";
    end;
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
