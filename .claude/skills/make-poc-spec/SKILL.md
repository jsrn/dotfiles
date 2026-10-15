---
name: make-poc-spec
description: Generate a proof-of-concept RSpec spec that demonstrates a bug or edge case from the problem(s) we're discussing, usually a code review finding. The spec is written against the local checkout, run, and never committed.
allowed-tools: Bash(bin/rspec:*), Bash(bundle exec rspec:*), Bash(git status:*)
---

# Make PoC spec

It's useful to show a code review finding in action with an example spec that
exposes the bug or edge case.

These specs are written locally and never committed.

## What the spec asserts

Assert the **correct** behaviour, so the spec **fails** on the current code.
The failure is the demonstration. If the finding is about something that
works but shouldn't (for example, a permission leak), assert that it is
refused.

Write one `it` per finding, named after the claim, for example
`it 'returns archived projects to guests'`.

## Writing for a human reader

These specs exist to show the issue to another person. So:

- Repeat set-up (for example, `let` assignments) when it makes the intent
  clearer, even if it isn't strictly needed.
- Comment the set-up to say what is being done and why.
- Don't worry about doing things the "right" way. Clarity beats convention,
  because these specs get thrown away.
- Give every expectation a custom failure message that says what the
  expected value is and why, for example
  `expect(result).to be_empty, "guests must not see archived projects, got #{result.map(&:id)}"`.
- Use `fast_spec_helper` when the code under test allows it. Otherwise use
  `spec_helper`.

## Where it goes

Mirror the path of the code under test under `spec/`, and prefix the file name
with `poc_`. For example, `app/finders/foo_finder.rb` becomes
`spec/finders/poc_foo_finder_spec.rb`. Never edit an existing spec file.

## Run it

Run the spec (`bin/rspec <path>`, or `bundle exec rspec <path>` if there is no
`bin/rspec`) and check that:

- it fails, and
- it fails for the reason in the finding, not because of a set-up or load
  error.

If it passes, the finding may be wrong. Say so rather than adjusting the spec
until it fails.

## Output

1. The spec, in a fenced block.
2. The relevant part of the failure output, in a fenced block, ready to paste
   into a review comment.
3. The file path(s) created, for cleanup. Run `git status` and confirm nothing
   is staged.
