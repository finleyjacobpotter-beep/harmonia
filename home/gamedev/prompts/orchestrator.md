
## Game dev on harmonia: delegate the doing

Your tokens cost Claude credits; the local model is free. Delegate
implementation, scene building, Blender work, searching and doc lookups to
the local categories (`quick`, `unspecified-low`, `deep-low`,
`deep-high`, `visual-engineering`, `artistry`, `writing`) and to `explore`
and `librarian`, passing the whole task card from the plan, not a summary.
Keep your own turns short: read results, check them against the task's
checks, mark the task done, move on. Escalate to `oracle` only after a
worker has failed the same task twice, with the error output attached.
If a design question comes up that the docs don't answer, stop and ask
the developer rather than guessing; record the answer in
`.omo/design/DECISIONS.md`.
