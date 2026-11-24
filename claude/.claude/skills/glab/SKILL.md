---
name: glab
description: Shared conventions for reading and commenting on a GitLab merge request with the glab CLI. Use when another skill (db-review, re-review) needs MR context, or when asked to read an MR's description, diff, discussions, versions or CI status, or to post review comments on an MR.
allowed-tools: Bash(glab mr view:*), Bash(glab mr diff:*), Bash(glab mr note list:*), Bash(glab mr note draft list:*), Bash(glab ci status:*), Bash(glab ci get:*), Bash(glab ci trace:*), Bash(git fetch:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git range-diff:*), Bash(glab orbit grep:*), Bash(glab orbit context:*), Bash(glab orbit query:*)
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
glab api user | jq -r .username            # who "me" is
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

### Orbit

When GitLab Orbit is available (`glab orbit --yes status` reports `HEALTHY`),
use it alongside the commands above. Load the `orbit` skill before writing
graph queries.

- `glab orbit context mr:<iid>` reads the description, review threads,
  changed files, and failed CI jobs in one call. Use it for a quick overview,
  but still fetch `discussions` and `versions` with `glab api` when you need
  discussion IDs, resolved state, or push history.
- `glab orbit context <path>:<start>-<end>` or `<name>` returns the code with
  its indexed callers and covering tests. Callers lists end in `+N more`; pass
  the `Definition:<id>` that `glab orbit grep` prints to get the full list.
- Graph answers for `gitlab-org/gitlab` use `project_id: 278964`. Calls are
  resolved inside one project only, and the graph can lag behind the latest
  push. Treat a result as evidence to check in the code, not as proof.

Other open MRs that touch the same files:

```
glab orbit query "MATCH (mr:MergeRequest {project_id: 278964, state: 'opened'}) -[:HAS_LATEST_DIFF]->(d:MergeRequestDiff) -[:HAS_FILE]->(f:MergeRequestDiffFile {project_id: 278964}) WHERE f.old_path IN ['<path>', '<path>'] AND mr.iid <> <iid> RETURN mr.iid, mr.title, f.old_path LIMIT 50"
```

## 3. CI

```
glab ci get --merge-request <iid> -F json  # latest MR pipeline and its jobs
glab ci trace <job-id>                     # a job's log, for failures
glab mr view <iid> --comments              # bot comments, e.g. database testing results
```

Report missing, failed, or still-running jobs that the review depends on. Do
not retry or trigger jobs unless asked.

## 4. Posting

These rules apply to every comment draft, posted or not:

- Put the Conventional Comments label, its decorations, and the colon in
  bold: `**issue (blocking):**`, not `issue (blocking):`.
- Write `**nitpick:**` with no decoration. A nitpick is non-blocking by definition.
- To cite a documented rule, link the published page on `docs.gitlab.com`
  with its section anchor, for example
  `[Punctuation](https://docs.gitlab.com/development/documentation/styleguide/text_and_formatting/#punctuation)`.
  Do not give a repository file path such as `doc/...` or `.ai/...`. Files
  under `.ai/principles/distilled/` are not published: link the page that
  states the rule, from the file's "Authoritative sources" list. Check that
  the URL and the anchor exist before you use them.

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
