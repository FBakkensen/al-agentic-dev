---
name: al-wayfinder
description: Use whenever /mattpocock-skills:wayfinder runs in an AL repository, to add the AL rules for which question becomes which ticket.
---

# al-wayfinder - which question becomes which ticket

In: `/mattpocock-skills:wayfinder` charting an effort in an AL repository. The entry skill owns the map, its decision tickets, and their blocking links. This addition supplies only when a question becomes which ticket.

## The rule

| Question | Ticket |
|---|---|
| A question one `/al-lookup` call answers | Never a ticket: run `/al-lookup` inline and carry its sourced answer into the map. |
| An investigation that needs several lookups across the AL sources | A research ticket. |
| A question about how logic should behave or how a page should look | A prototype ticket. |

Every other question takes the entry skill's own ticket types.

## Close

Done when every question the charting raised is answered inline with its `/al-lookup` source or placed as a ticket by the table. The placement goes back to the `/mattpocock-skills:wayfinder` run.
