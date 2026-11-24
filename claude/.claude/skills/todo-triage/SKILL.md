---
name: todo-triage
description: Triage my pending GitLab TODOs into Taskwarrior (GitLab TODOs are the inbox, Taskwarrior is the single source of truth), then report my work tasks as a prioritised list (Act now / Review today / Assigned / Mark done), with the review type, size and urgency of each review request, and mark tasks done one by one after I confirm. Use when asked to "triage my TODOs", "go through my todos", "what's in my GitLab inbox", "what should I review today", or "what's waiting on me".
allowed-tools: Bash(~/.claude/skills/todo-triage/scripts/gather.sh:*), Bash(jq:*), Bash(mktemp:*), Bash(glab api user:*), Bash(glab api projects/:*), Bash(glab api -X POST todos/:*), Bash(task project:work status:pending export)
---

# TODO triage

GitLab TODOs are an inbox. Each actionable TODO becomes a Taskwarrior task,
and then its TODO is marked done, so Taskwarrior is the single source of truth.
GitLab makes a new TODO for each new event, so nothing is lost.

Follow the `glab` skill's conventions for reading MR context. Never post,
resolve, approve or edit anything on GitLab. The only writes this skill makes
are marking a GitLab TODO done, and adding, annotating or completing a
Taskwarrior task, each only after I confirm that item.

## 1. Gather

```
out=$(mktemp -d) && ~/.claude/skills/todo-triage/scripts/gather.sh "$out"
```

This writes `$out/items.json`: one entry per MR or issue. It has every TODO
target (several TODOs on the same target are grouped in `todos`), and every
target that a pending task links to, even with no TODO (`todos: []`). `tasks`
lists the uuids of the tasks that link to the target. `context` has the labels,
milestone, reviewer states (`i_am_reviewer`), approvals, push history, my last
note, my unresolved threads, my unsubmitted draft notes, and per-file `+/-`
line counts. Two special cases:
- `context: null`: a task-only target that is merged or closed.
- `context.group_work_item: true`: a group-level work item (an epic). The
  script cannot read it, so read it with `glab orbit context` when it matters.

Read it with `jq` rather than dumping it whole. Only call `glab api` for more
when the summary leaves a real question open, such as what a long thread
concluded.

**Do not check pipeline state.** It is not part of this triage.

glab quirks, already handled in the script, to remember for ad-hoc calls:
- glab 1.131 has no `--jq`; pipe to `jq`.
- `--paginate` concatenates arrays; use `jq -s 'add'`.
- Run loops under `bash -c`, because zsh does not word-split `$var`.
- `issues/:iid` 404s in `gitlab-com/request-for-help`, but `issues/:iid/notes` works.

### Taskwarrior

The script also writes `$out/tasks.json`: every pending task in `work` and its
sub-projects, with `uuid`, `description`, `project`, `due`, `scheduled`,
`priority`, `tags`, `annotations` and `urgency`, plus:
- `links`: each GitLab MR or issue URL in the description or annotations, with
  its `target` (the `items.json` url), `state` and `title`. `checked: false`
  means a group-level work item.
- `blocked`: true when the task depends on another pending task.
- `await`: for a task tagged `+await`, the last `#note_` link is the anchor,
  and `replies` lists the non-system notes by other people after it.
  `anchor_found: false` means the note was not found on that item.

Tags: `+review` (a review I owe), `+await` (waiting for a reply), `+read`,
`+watch` and `+quick` (low-effort work).

## 2. Assess each review request

For every MR in `items.json` with a review TODO, or linked to a `+review`
task, work out the items below. A `+review` task has no TODO after the first
triage, so this context is the only way to see that the author asked again or
that approvals changed. If `i_am_reviewer` is false on a `+review` task's MR, I
was removed as a reviewer: offer the task in **Mark done**.

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

## 3. Assess each Taskwarrior task

- **Linked to a GitLab item:** find it in `items.json` by the link `target`.
  Several tasks on one item share a row, and the category follows the item and
  its context. If the item is merged or closed, the task goes in **Mark done**,
  except a `+read` or `+watch` task: reading a merged MR is still to do.
- **`blocked`:** leave it out of the tables, and give the count and what
  blocks it in the line under the report.
- **`+await`:** if `replies` has a note from the person the task names, put the
  task in **Act now**, say who replied and when, and offer it in **Mark done**.
  A reply from someone else does not count, but mention it in **Why**. With no
  reply, use the usual rules below; `scheduled` in the future is not overdue.
- **Not linked:** put it in **Act now** if it's overdue, due today or
  `priority:H`. Put it in **Review today** if it's due within 2 working days or
  `priority:M`. Leave the rest out of the tables, and give their count in a
  single line under the report, with the count of `+read`, `+watch` and
  `+quick` tasks among them.
- Within a category, order tasks by `urgency`, highest first.

## 4. Process the inbox

Do this before the report. For each item in `items.json` with `todos`, choose
one action:

- **Annotate:** a task already links to the item (`tasks` is not empty).
  Add the new event to that task, so its history stays in one place.
- **New task:** the TODO needs something from me, and no task links to it.
- **Done, no task:** the TODO needs nothing from me (thanks, FYI, settled
  threads, ccs superseded elsewhere, merged or closed targets, MRs I am not a
  reviewer on).
- **Keep:** my own MR waiting on me, or unsubmitted draft notes. GitLab is the
  source of truth for these, so the TODO stays and the item goes in the report
  from `items.json`.

Ask with AskUserQuestion, one question per item and up to 4 per call. Put the
proposed action and a one-line reason in the question, and give the proposed
action first, with "(Recommended)". The options are the four actions above.

For **New task**, set the fields from steps 2 and 3:
- Description: "Review !<iid>: <title>" for a review, otherwise a short
  imperative ("Reply to obaiye on &8985 timeline").
- `project:work.reviews` for reviews; otherwise the `work` sub-project that
  fits (`work.retention`, `work.admin`), or `work`.
- `+review` for reviews; `+await` only when I am waiting for someone.
- `priority:H` for Act now, `priority:M` for Review today, otherwise `priority:L`.
- `due:` only for a real deadline, such as a milestone or SLO date.

```
task rc.confirmation=off add project:<project> priority:<H|M|L> +<tag> -- "<description>"
uuid=$(task +LATEST _uuids)
task "$uuid" annotate -- "<TODO target_url>"
task "$uuid" annotate -- "<action> by <author> <created>: <first line of body>"
```

Check that `task "$uuid" export` shows the new description before you go on.
`+LATEST` is the task added last, so run these commands for one task at a time.

For **Annotate**, run `task <uuid> annotate -- "<action> by <author> <created>:
<first line of body> <target_url>"` on each linked task, and change its
`priority` if the event makes it more urgent.

Then, for **New task**, **Annotate** and **Done, no task**, mark every TODO on
the item done:

```
glab api -X POST todos/<id>/mark_as_done
```

Never use `todos/mark_as_done` (which marks everything done). Run Taskwarrior
loops under `bash -c`, because zsh does not word-split `$var`.

## 5. Categorise

Build the report from the tasks (step 3, with the review assessment from step
2), plus the items kept in step 4.

- **Act now:** my own MRs waiting on me; unsubmitted draft notes (the author can't see them); urgent reviews from step 2.
- **Review today:** other review requests, ordered by urgency and then size (quick wins first when urgency ties).
- **Assigned:** tasks for issues assigned to me. Say what the issue currently needs from me, if anything.
- **Mark done:** tasks whose work is finished: merged or closed targets, an `+await` task with the reply it waited for, a `+review` task where I'm no longer a reviewer.

## 6. Output

One table per category, using the same layout every day.

| # | Item | Type | Size | Why |
|---|---|---|---|---|

- Put the link and title in **Item**, and leave out Type and Size for non-review items.
- For a task linked to a GitLab item, put the item link and title in **Item**, and "Task `<first 8 chars of uuid>`" after it.
- Give a task with no link as "Task `<first 8 chars of uuid>`: description" in **Item**, and give its due date and priority in **Why**.
- Keep **Why** to one or two sentences: what's being asked, who's waiting, and what changed since I last looked.
- Head the report with the date and counts ("15 TODOs across 11 items, 6 work tasks").
- Under the report, say what step 4 did: tasks added, tasks annotated, TODOs marked done, TODOs kept.

## 7. Mark done, one item at a time

After the report, ask about each item in **Mark done**. Use AskUserQuestion
with one question per item and up to 4 per call. Use the options "Mark done"
and "Keep", and put the one-line reason in the question.

For each task I confirm, run this with its full uuid:

```
task <uuid> done
```

Always use the uuid, never a filter or a short id. A filter can complete
several tasks at once, and short ids change as tasks are completed. For a kept
item from step 4 that I confirm, mark its TODOs done as in step 4.

Report what was marked done and what was kept.
