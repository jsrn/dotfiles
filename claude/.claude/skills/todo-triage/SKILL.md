---
name: todo-triage
description: Triage my pending GitLab TODOs into a prioritised list (Act now / Review today / Assigned / Mark done), with the review type, size and urgency of each review request, then mark TODOs done one by one after I confirm. Use when asked to "triage my TODOs", "go through my todos", "what's in my GitLab inbox", "what should I review today", or "what's waiting on me".
allowed-tools: Bash(~/.claude/skills/todo-triage/scripts/gather.sh:*), Bash(jq:*), Bash(mktemp:*), Bash(glab api user:*), Bash(glab api projects/:*), Bash(glab api -X POST todos/:*)
---

# TODO triage

Follow the `glab` skill's conventions for reading MR context. Never post,
resolve, approve or edit anything on GitLab. The only write this skill makes
is marking a TODO done, and only after I confirm that item.

## 1. Gather

```
out=$(mktemp -d) && ~/.claude/skills/todo-triage/scripts/gather.sh "$out"
```

This writes `$out/items.json`: one entry per target (several TODOs on the same
MR or issue are grouped), with the triggering comments, labels, milestone,
reviewer states, approvals, push history, my last note, my unresolved threads,
my unsubmitted draft notes, and per-file `+/-` line counts.

Read it with `jq` rather than dumping it whole. Only call `glab api` for more
when the summary leaves a real question open, such as what a long thread
concluded.

**Do not check pipeline state.** It is not part of this triage.

glab quirks, already handled in the script, to remember for ad-hoc calls:
- glab 1.131 has no `--jq`; pipe to `jq`.
- `--paginate` concatenates arrays; use `jq -s 'add'`.
- Run loops under `bash -c`, because zsh does not word-split `$var`.
- `issues/:iid` 404s in `gitlab-com/request-for-help`, but `issues/:iid/notes` works.

## 2. Assess each review request

For every MR where I'm a reviewer, or where someone asks me to review, work out:

**Review type.** Use these signals, strongest first:
1. An explicit ask in the mention ("Webhooks review", "database review", "maintainer review").
2. The reviewer-roulette row that names me (`roulette_row`), if any.
3. Labels such as `database` (with `database::review pending` meaning a DB review is still needed), `backend`, `frontend` and `documentation`.
4. Changed paths: `db/migrate`, `db/post_migrate` and `db/structure.sql` mean database; `app/assets`, `*.vue` and `spec/frontend` mean frontend; `lib/api` and `app/graphql` mean API; `doc/` means docs.
5. The domain: webhooks (`web_hook*`, `hooks`) or import (`bulk_imports`, `import/`, `gitlab/github_import`).

Give the type as e.g. "Backend + webhooks domain" or "Frontend (re-review)".

**Size: S / M / L.** Leave out spec files and generated files (`openapi_v3.yaml`,
`all_queues.yml`, `structure.sql` noise) when counting.
- **S:** at most about 50 non-spec lines in at most 3 files, with nothing structural.
- **M:** up to about 300 non-spec lines.
- **L:** more than that, or anything structural (new tables or migrations, a new worker or cron job, a new service class, changed shared concerns) whatever the line count.
- For a re-review, size the change since my last note (pushes after `my_last_note`), not the whole MR, and say so.

**Urgency.** The question is whether my review is unblocking another engineer.
Move a review up to **Act now** when any of these hold:
- My approval is still required: `approvals_left > 0` and I hold a required category, or I'm the only reviewer still to approve.
- The author addressed my earlier feedback and asked me again.
- It's a bug fix, security or ~infradev work, has a severity or priority label, or its milestone is due within about a week.
- The author is a teammate (same `group::` label as my team, which is `group::import`) and the MR is otherwise ready.
- It was requested more than 2 working days ago with no response from me.

Move it down when `approvals_left == 0` and my category isn't required, when
the ask says "when you have time" and nothing above applies, or when it's
docs-only.

## 3. Categorise

- **Act now:** my own MRs waiting on me; unsubmitted draft notes (the author can't see them); urgent reviews from step 2.
- **Review today:** other review requests, ordered by urgency and then size (quick wins first when urgency ties).
- **Assigned, no TODO action needed:** `assigned` TODOs on issues. Say what the issue currently needs from me, if anything.
- **Mark done:** TODOs needing nothing from me: thanks or FYI mentions; MRs I'm no longer a reviewer on; settled threads; ccs superseded elsewhere; merged or closed targets.

## 4. Output

One table per category, using the same layout every day.

| # | Item | Type | Size | Why |
|---|---|---|---|---|

- Put the link and title in **Item**, and leave out Type and Size for non-review items.
- Keep **Why** to one or two sentences: what's being asked, who's waiting, and what changed since I last looked.
- Head the report with the date and counts ("15 TODOs across 11 items").
- Finish with a line saying nothing on GitLab has been changed yet.

## 5. Mark done, one item at a time

After the report, ask about each item in **Mark done**, and then any others
where marking the TODO done is reasonable, such as Assigned items. Use
AskUserQuestion with one question per item and up to 4 per call. Use the
options "Mark done" and "Keep", and put the one-line reason in the question.

For each item I confirm, mark every TODO on that item done:

```
glab api -X POST todos/<id>/mark_as_done
```

Report what was marked done and what was kept. Never use `todos/mark_as_done`
(which marks everything done).
