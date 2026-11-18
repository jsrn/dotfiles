---
name: glab
description: Shared conventions for reading and commenting on a GitLab merge request with the glab CLI. Use when another skill (db-review, re-review) needs MR context, or when asked to read an MR's description, diff, discussions, versions or CI status, or to post review comments on an MR.
allowed-tools: Bash(glab mr view:*), Bash(glab mr diff:*), Bash(glab mr note list:*), Bash(glab mr note draft list:*), Bash(glab ci status:*), Bash(glab ci get:*), Bash(glab ci trace:*), Bash(git fetch:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git range-diff:*)
---

# Working with a merge request via glab

## 1. Resolve the MR

Accept any of:

| Input | How to use it |
| --- | --- |
| IID (`12345`, `!12345`) | Pass the number to `glab mr ...` from inside the project checkout. |
| URL (`https://gitlab.com/<path>/-/merge_requests/<iid>`) | Take `<path>` and `<iid>`. Pass `-R <path>` to `glab mr ...` if `<path>` is not the current checkout's project. |
| Branch name | `glab mr view <branch>`. |
| Nothing | `glab mr view` with no argument uses the current branch's MR. If there is none, say so and stop. |

`glab api` has no `-R`. Use `:fullpath` when the MR is in the current checkout's
project; otherwise URL-encode the path (`gitlab-org%2Fgitlab`).

## 2. Read the context

```
glab mr view <iid> -F json                 # title, description, labels, author, sha, diff_refs, web_url
glab mr diff <iid>                         # full diff of the latest version
glab api user --jq .username               # who "me" is
glab api --paginate projects/:fullpath/merge_requests/<iid>/discussions
glab api projects/:fullpath/merge_requests/<iid>/versions
```

- Read the MR description in full. It often holds query plans, timings, and
  the reasons behind choices.
- `diff_refs` gives `base_sha`, `start_sha` and `head_sha`. To diff locally,
  `git fetch origin` and run `git diff <base_sha>...<head_sha>`. Do not diff
  against a local `master`, which may be stale.
- Each entry in `versions` is one push, with `head_commit_sha`,
  `base_commit_sha` and `created_at`, newest first. Use these to find what
  changed between two points in the MR's history.
- Discussions include system notes. Filter on `notes[].system == false`
  when you want human comments only.

If the local checkout's `HEAD` is not the MR's `head_sha`, say so. Line numbers
from the working tree may not match the MR.

## 3. CI

```
glab ci get --merge-request <iid> -F json  # latest MR pipeline and its jobs
glab ci trace <job-id>                     # a job's log, for failures
glab mr view <iid> --comments              # bot comments, e.g. database testing results
```

Report missing, failed, or still-running jobs that the review depends on. Do
not retry or trigger jobs unless asked.

## 4. Posting

Never post, resolve, or edit anything on GitLab unless the user asks.

When asked:

- Show the user the exact text first, and post only after they confirm.
- Wrap every body in `<:robot:>` / `</:robot:>` so readers know it was drafted
  by an agent.
- Prefer draft notes, so the user publishes the review themselves:
  - Line comment: `glab mr note draft create <iid> --file <path> --line <n> -m '<body>'`
  - Reply in a thread: `glab mr note draft create <iid> --reply <discussion-id> -m '<body>'`
  - Use `--old-line` for a removed line.
- Use `glab mr note create` (published right away) only when the user asks
  for it explicitly. Add `--unique` to avoid posting the same note twice.
- Never run `glab mr note draft publish`, approve, or merge for the user.
