---
description: Do the next unticked task from the plan on the local model (free)
agent: ornith
---

Find the newest plan in `.omo/plans/` and its first unticked task whose
dependencies are ticked (or the task named here: $ARGUMENTS). Read the
design docs its card relies on, then do it exactly as the card says, run
all of its checks through the `godot` server, fix what fails, tick it and
commit with the task id in the message. Stop after that one task and
summarise what changed.
