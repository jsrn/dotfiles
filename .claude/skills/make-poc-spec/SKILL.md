---
name: make-poc-spec
description: Generate a proof-of-concept spec for the problem(s) we're
  discussing. These specs should be made against the local checkout and not
  committed.
---

# Make PoC spec

It's useful to demonstrate code review findings with an example spec that shows
a bug or edge-case in action.

These specs should be made locally, but not committed.

These specs are intended to demonstrate the issue to another human being. Thus:

- Duplicate test set-up (e.g. `let` assignments) that clarify test intent, even
  if not strictly necessary.
- Comment the test set-up to explain what is being done and why.
- Do not worry about doing things the "right" way. Clarity trumps convention, as
  these specs should be discarded.
- When writing expectations, supply a custom error message that clearly shows
  what the expected value is and why.

