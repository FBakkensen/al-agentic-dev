# al-next

## What it is for

The navigator. It reads the feature's `tasks/` folder, works out which moves the current state makes viable, and presents them. It runs nothing and writes nothing — you take the step.

This is where the routing lives now. There is no status board and no replan ceremony; the task files are the state, and this skill reads them.

## When you reach for it

- Any other skill just closed. Every one of them ends by pointing here.
- You are picking a feature back up after a break and need to know where it stands.
- You want to know what is blocked, and on what.
- Nothing is written down yet — it will point you at the right cold-start skill.

## What it produces

One line per viable move in chat: the `T-NNN`, the skill that owns it, and the state that makes it viable — in the feature's own object and field names, not in categories. Where several moves are open at once it lists them in order and says which one unblocks the most downstream work. Where nothing is reachable it names the one thing that has to settle, and who settles it.

No file changes.
