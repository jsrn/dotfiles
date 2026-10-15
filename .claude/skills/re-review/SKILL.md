---
name: re-review
description: Review changes to an MR since my last round of review comments. Use when asked to "re-review", do a "follow-up review", "check the MR again", or check whether the author "addressed my comments" or "responded to my feedback".
argument-hint: <mr-iid-or-url>
allowed-tools: Bash(glab mr view:*), Bash(glab mr diff:*), Bash(glab mr note list:*), Bash(git fetch:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git range-diff:*)
---

# Re-review

Review only what changed since my last round of comments, and check each
earlier comment was dealt with properly.

Follow the `glab` skill to resolve the MR and read its context.

## 1. Find my last round

1. Get my username: `glab api user --jq .username`.
2. Fetch all discussions (`--paginate`). Keep the non-system notes I wrote.
   The newest `created_at` among them is the **baseline time**. If I have no
   comments on the MR, say so and stop.
3. Fetch the MR `versions`. The **baseline version** is the newest version
   whose `created_at` is before the baseline time. The **current version** is
   the newest overall.
4. If they are the same version, nothing has been pushed since my comments.
   Report only on the author's replies (section 2), then stop.

## 2. Gather what changed

- Fetch both head SHAs: `git fetch origin <baseline_head> <current_head>`.
  If the server refuses to fetch by SHA, use the compare API instead:
  `glab api "projects/:fullpath/repository/compare?from=<baseline_head>&to=<current_head>&straight=true"`.
- If the base SHA is the same in both versions, review
  `git diff <baseline_head> <current_head>`.
- If the base moved (rebase or force-push), a plain diff would pull in
  unrelated `master` changes. Use
  `git range-diff <baseline_base>..<baseline_head> <current_base>..<current_head>`
  to see what changed in the author's commits, then read the affected files
  at `<current_head>`.
- For each of my threads, read every reply after my note, including on
  resolved threads. Note who resolved each thread.

## 3. Evaluate

For each of my earlier comments:

- **Fixed**: check the fix in the code at `<current_head>`. Don't rely on
  the author's word or on the thread being resolved.
- **Pushed back**: decide whether the reason holds up. Say so either way,
  and why.
- **Not addressed**: no matching code change and no reply. Flag threads
  that were resolved without either.

For the new changes as a whole:

- Do they introduce new problems, including regressions in code that was
  already reviewed?
- Do they meet the same quality bar as new code? Fixes don't get a lighter
  review.
- Where a change brings in a new tradeoff, give up to three pros and cons.

If a finding is disputed or subtle, offer to demonstrate it with
`/make-poc-spec`.

## 4. Report

1. **Summary**: one line. Ready for approval, or what is still blocking.
2. **Earlier comments**: one row per thread.

   | # | Thread (`path:line` or topic) | Status | Notes |
   | --- | --- | --- | --- |
   | 1 | `app/models/foo.rb:42` | Fixed (verified) | |
   | 2 | N+1 in `BarFinder` | Pushed back: agree | Batched upstream |
   | 3 | Missing spec | Pushed back: disagree | Reason: … |
   | 4 | Naming | Not addressed | Resolved without change |

3. **New findings**: numbered, each with `path:line`, severity
   (blocker / improvement / nit), and a concrete fix.
4. **Checked and OK**: the risky parts of the new changes you verified.

Do not post to GitLab unless asked. If asked, follow the posting rules in the
`glab` skill. Replies to existing threads go in that thread with `--reply`.
