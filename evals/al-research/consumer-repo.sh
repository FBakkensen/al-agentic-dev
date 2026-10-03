#!/usr/bin/env bash
# Seeds an AL Consumer repository: an app and its source.
set -euo pipefail

mkdir -p src

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

git init -q
git -c core.autocrlf=false add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "ShopFloor app"
