---
name: daily-update
description: Draft my post for the team's daily update thread — the work I did since my last update, from ~/Desktop/work.md, and today's priorities as themes, from Taskwarrior. Use at the end of a morning `todo-triage` run, and when asked for "my daily update", "standup post", "what did I do since my last update", or "a report of my work on <days> and my priorities today".
allowed-tools: Read(~/Desktop/work.md), Bash(date:*), Bash(task project:work status:pending export), Bash(jq:*), Bash(cat ~/.local/state/daily-update/last:*), Bash(mkdir -p ~/.local/state/daily-update:*), Bash(glab orbit context:*)
---

# Daily update

Draft one post with two sections: the work I did since my last update, and
my priorities for today. Give the post to me in a fenced `markdown` block, so
I can copy it. Do not post it anywhere yourself.

## 1. Find the range of previous work

1. Get today's date with `date '+%Y-%m-%d'`. Do not assume it.
2. Read the date of my last update: `cat ~/.local/state/daily-update/last`.
3. The range is every day in `~/Desktop/work.md` after that date and before
   today.
4. If I name the days ("Monday and Tuesday"), use those days instead.
5. If the file does not exist, or the range is empty, use the last day
   before today that has a heading in `~/Desktop/work.md`.

Never include today's block in the previous work. Work I started today is
part of today's priorities.

## 2. Previous work

Read `~/Desktop/work.md` in full. Merge all days in the range into **one**
section, even when the range has more than one day:

- Heading: the range, in the `work-log` date format. One day:
  `# 24th November 2026`. More than one day: `# 23rd–24th November 2026`, or
  `# 28th November–2nd December 2026` across a month boundary.
- Sections in the order `Code`, `Review`, `Other`, with 4-space indents, as in
  the `work-log` skill. Include a section only when it has an entry.
- Copy each entry exactly as it is in the log, in date order. Do not reword,
  add or remove detail.
- If the same link occurs on more than one day in the same section, keep the
  first entry only.

## 3. Today's priorities

Heading: `# Priorities for <today in the work-log date format>`.

Summarise the priorities as **themes**, one bullet each. A theme is a project
or a stream of work, not a task. Each bullet has:

- The theme name, then the link to its main issue or epic when it has one.
- A colon, then one short clause on the direction of work today.

Example:

```markdown
- Webhook log retention ([#605238](https://gitlab.com/gitlab-org/gitlab/-/work_items/605238)): agree the structure (epic or not), turn the breakdown into tracked sub-issues, and unblock weekday partition drops.
- Reviews: two backend MRs that others requested yesterday.
```

The level of detail is important:
- Too specific: one bullet per task, or a list of the steps in a theme.
- Too vague: only the theme names, with no clause.

### Sources

- If `todo-triage` ran in this session, use its result: the tasks in **Act
  now**, **Review today** and **Assigned**, after its **Mark done** step.
- If not, run `task project:work status:pending export` and use the tasks
  that are overdue, due within 2 working days, or `priority:H` or
  `priority:M`. Leave out blocked tasks.
- Add the MRs and issues in today's block of `~/Desktop/work.md` that are
  not finished (for example, a review that I started today).

### Group into themes

- Group by Taskwarrior `project`: `work.reviews` is **Reviews**, `work.admin`
  is **Admin**, and each other sub-project is one theme.
- Put a task in the plain `work` project into the theme of the epic or issue
  that it links to. Give the theme a short name from that title (for example,
  &8985 is **Offline transfer**). If it links to nothing, put it in the theme
  that it fits best, or leave it out.
- Name a sub-project theme from its main issue, not from the project name
  (`work.retention` is **Webhook log retention**).
- For **Reviews**, give the count and the type, not the MR titles.
- Leave out `+read` and `+watch` tasks, unless one is due today.
- Order the themes by the most urgent task in each theme.

## 4. Output and record

1. Give me the post in one fenced `markdown` block: previous work first, then
   the priorities.
2. Under the block, write one line for each thing that I must check, for
   example: a day in the range that has no entries, or a `priority:H` task
   with no context that I left out.
3. Record today's date as the date of my last update:

   ```
   mkdir -p ~/.local/state/daily-update && date '+%Y-%m-%d' > ~/.local/state/daily-update/last
   ```

When I ask for changes to the post, change the post and give it again. Do not
write the date again.
