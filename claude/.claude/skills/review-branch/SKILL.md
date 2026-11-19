---
name: review-branch
description: Deep review of the MR for my current local branch, or of a given MR checked out into a separate worktree — run code-review, then filter the findings against the MR's existing discussion and the work item's intent, verify each one (with PoC specs where useful), check test gaps, and walk me through the surviving findings one at a time. Use when asked to "review my branch", "review this MR properly", "deep review", or to triage code-review findings before posting. Applies the security MR process on `security-` branches.
argument-hint: "[low|medium|high|xhigh] [mr-iid-or-url]"
allowed-tools: Bash(glab mr view:*), Bash(glab mr diff:*), Bash(glab mr note list:*), Bash(glab issue view:*), Bash(git fetch:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git blame:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git status:*), Bash(git worktree list:*), Bash(glab mr checkout:*), Bash(ln -s:*), Bash(bin/rspec:*), Bash(bundle exec rspec:*)
---

# Review branch

Review the MR for the current branch, then cut the findings down to the ones
that are real, new, and caused by this MR, and present them one at a time.

Arguments: an optional effort level for `code-review` (default `high`) and an
optional MR. With no MR, use the current branch's MR. Follow the `glab` skill
to resolve the MR and read its context.

## 0. Worktree (only when an MR is passed)

Leave my current checkout untouched. If the MR's source branch is the branch
already checked out here, skip this section and review in place.

1. Check out the MR into a worktree:
   `glab mr checkout <mr> --worktree .claude/worktrees/mr-<iid>` (add
   `-R gitlab-org/security/gitlab` for security MRs). If the branch is
   already checked out in another worktree, add `--branch review-mr-<iid>`.
   Re-running on an existing path updates it.
2. Symlink the main checkout's git-ignored GDK config into the worktree so
   specs can run. These are every file listed by
   `git status --ignored --porcelain config` in the main checkout
   (`config/database.yml`, `config/gitlab.yml`, `config/redis.*.yml`, etc.):
   `ln -s <main>/config/<file> <worktree>/config/<file>`.
3. Switch the session into it with `EnterWorktree` (`path`), and run every
   later step from there.

The worktree shares GDK's databases. If the MR changes `db/structure.sql`,
warn me before running PoC specs, and don't migrate the test database
without asking.

## 1. Context first

Gather this before reviewing, so intent shapes what counts as a finding.

- **Branch type**: if the MR's source branch starts with `security-`, the
  MR lives in `gitlab-org/security/gitlab`, not the canonical project. Pass
  `-R gitlab-org/security/gitlab` to `glab mr` and see section 6.
- **MR**: description, diff refs, and all non-system discussions (resolved and
  unresolved), per the `glab` skill. If local `HEAD` is not the MR's
  `head_sha`, say so before going further.
- **Work item**: find it from `Closes`/`Related to` links in the description,
  or an issue number in the branch name. Read it with `glab issue view` (or
  `glab api` for work items/epics) including comments. Summarise the intended
  behaviour and any acceptance criteria in 2-3 lines. If there is no work item,
  say so and use the MR description as the statement of intent.

## 2. Run code-review

Invoke the `code-review` skill at the chosen level against the MR's diff
(`<base_sha>...<head_sha>`), not against a local `master`. Collect every
finding, uncertain ones included; filtering happens below.

Then do your own pass for **test gaps**: for each changed behaviour, is there
a spec that would fail if it regressed? Look especially for untested
branches/early returns, negative and permission-denied paths, nil/empty
inputs, and EE vs FOSS differences. Treat each gap as a finding.

## 3. Name each finding

Give each finding a short kebab-case ID of the form `<area>-<problem>-<n>`,
for example `api-auth-bypass-1`, `finder-n-plus-one-1`, `spec-missing-guest-1`.
Keep IDs stable for the rest of the session so I can refer to them.

## 4. Filter and verify

For each finding, record:

1. **Already raised?** Match it against the MR discussions. If a thread
   covers it, note the thread and its outcome: fixed (check the code at
   `head_sha`, don't trust the reply or resolved state), pushed back (does the
   reason hold?), or open. Drop findings that were fixed or convincingly
   rebutted.
2. **Caused by this MR?** Use the diff and `git blame` on the base to decide
   whether the MR introduced the problem, or made it newly reachable or worse.
   A problem that exists unchanged on the base is pre-existing: drop it from
   the main list but keep a one-line note of it.
3. **In scope?** Compare against the work item's intent. A finding that
   contradicts the stated intent is a blocker; one that asks for work the
   issue explicitly defers is not.
4. **Verified?** Confirm by reading the code paths end to end. For
   behavioural claims (wrong result, permission leak, crash, data loss), use
   the `make-poc-spec` skill to demonstrate it. Skip the PoC for style,
   naming, or design findings. Mark each as **Confirmed**, **Plausible**
   (couldn't prove it, explain why), or **Refuted** (drop it).

## 5. Present

Start with one summary block:

- Intent of the change (from section 1), in one line.
- Count of findings raised, dropped (already addressed / pre-existing /
  refuted), and remaining.
- The remaining IDs in order, most severe first, each with severity
  (blocker / improvement / nit) and a ≤10-word label.
- Pre-existing issues noticed, one line each, if any.

Then present the remaining findings **one at a time**, most severe first.
For each:

- **ID**, severity, verdict (Confirmed / Plausible), `path:line`.
- The problem in 1-2 sentences, and the concrete failure scenario.
- Evidence: the PoC spec failure output, or the code path that proves it.
- A suggested fix.
- A draft review comment: point first, justification in `<details>`,
  wrapped per the `glab` skill's posting rules.

Then stop and wait for my verdict on that finding (for example: keep, drop,
reword, post) before showing the next one. Track my decisions and, after the
last finding, list the kept IDs with their final comment text.

Do not post anything to GitLab unless I ask; then follow the `glab` skill's
posting rules. List any `poc_*_spec.rb` files created so I can clean them up.

If you created a worktree, stay in it until I'm done, then return with
`ExitWorktree` (`keep`) and give me the cleanup command:
`git worktree remove --force .claude/worktrees/mr-<iid>` (`--force` because
of the config symlinks and PoC specs). Never remove it yourself unasked.

## 6. Security branches

When the branch starts with `security-`, also review against the security
process. Read `.ai/security-fixes.md` and
`.gitlab/merge_request_templates/Security Fix.md` in the checkout, then check:

- The MR targets `master` or an `X-Y-stable-ee` branch on
  `gitlab-org/security/gitlab`, and links the security implementation issue.
- A changelog entry is present with the `Changelog: security` trailer.
- The fix closes the vulnerability completely: look for sibling entry points
  (REST, GraphQL, internal API, other controllers or services) that reach the
  same code without the new check.
- A spec reproduces the original vulnerability and would fail without the fix.
- If the fix changes default behaviour that could block legitimate use, it
  ships with an admin opt-out or other console-free remediation path.
- Nothing in the code, comments, specs or commit messages discloses the
  vulnerability beyond what is necessary.

Report checklist gaps as findings with a `security-` ID prefix. Never post
to, or cross-link from, any public issue or MR.
