#!/usr/bin/env bash
# Seeds an AL Consumer repository whose app has no namespaces: objects by type
# in one folder, as a C/AL conversion leaves them, committed and clean.
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
        field(2; "Default Location Code"; Code[10]) { }
    }
}
AL

cat > src/ShopFloorSetupCard.Page.al <<'AL'
page 50101 "ShopFloor Setup Card"
{
    PageType = Card;
    SourceTable = "ShopFloor Setup";

    layout
    {
        area(Content)
        {
            field("Default Location Code"; Rec."Default Location Code") { }
        }
    }
}
AL

cat > src/WorkCenterLoad.Table.al <<'AL'
table 50102 "Work Center Load"
{
    fields
    {
        field(1; "Work Center No."; Code[20]) { }
        field(2; "Load Date"; Date) { }
        field(3; "Planned Hours"; Decimal) { }
    }
}
AL

cat > src/WorkCenterLoadMgt.Codeunit.al <<'AL'
codeunit 50103 "Work Center Load Mgt"
{
    procedure AddLoad(WorkCenterNo: Code[20]; LoadDate: Date; Hours: Decimal)
    var
        WorkCenterLoad: Record "Work Center Load";
    begin
        WorkCenterLoad."Work Center No." := WorkCenterNo;
        WorkCenterLoad."Load Date" := LoadDate;
        WorkCenterLoad."Planned Hours" := Hours;
        WorkCenterLoad.Insert(true);
    end;
}
AL

cat > src/DispatchList.Table.al <<'AL'
table 50104 "Dispatch List"
{
    fields
    {
        field(1; "Entry No."; Integer) { }
        field(2; "Prod. Order No."; Code[20]) { }
    }
}
AL

cat > src/DispatchMgt.Codeunit.al <<'AL'
codeunit 50105 "Dispatch Mgt"
{
    [IntegrationEvent(false, false)]
    local procedure OnAfterDispatch(var DispatchList: Record "Dispatch List")
    begin
    end;

    procedure Dispatch(ProdOrderNo: Code[20])
    var
        DispatchList: Record "Dispatch List";
    begin
        DispatchList."Prod. Order No." := ProdOrderNo;
        DispatchList.Insert(true);
        OnAfterDispatch(DispatchList);
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
