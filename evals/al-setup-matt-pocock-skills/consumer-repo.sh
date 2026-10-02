#!/usr/bin/env bash
# Seeds an AL Consumer repository that has not been set up for the engineering
# skills: an app and its source, with no tracker doc and no Agent skills block.
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
    }
}
AL

git init -q
git -c core.autocrlf=false add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "ShopFloor app"
