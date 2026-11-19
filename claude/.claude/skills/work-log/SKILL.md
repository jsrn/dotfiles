---
name: work-log
description: Add an entry to my daily work log at ~/Desktop/work.md. Use after I finish a unit of work in the session — a code review or re-review of an MR, posting review comments, opening or pushing to an MR, or picking up an issue or work item — and when I ask to "log this", "add to my work log", or "note this in work.md".
argument-hint: "[code|review|other] [note]"
allowed-tools: Read(~/Desktop/work.md), Edit(~/Desktop/work.md), Write(~/Desktop/work.md), Bash(date:*), Bash(glab mr view:*), Bash(glab issue view:*), Bash(glab orbit context:*)
---

# Work log

Record what I did in `~/Desktop/work.md`, under today's date heading.

## File format

```markdown
# 19th November 2026

- Code:
    - Picked up [Explore archiving webhook logs to object storage](https://gitlab.com/gitlab-org/gitlab/-/work_items/605238).
- Review:
    - [Mark default webhook payloads with a signed body field](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268146).
- Other:
    - Re-enrolling in MDM stuff.
```

- Date heading: `# <ordinal day> <full month> <year>`. Ordinals: 1st, 2nd,
  3rd, 4th–20th, 21st, 22nd, 23rd, 24th–30th, 31st. Get the date from
  `date '+%-d %B %Y'`; do not assume it.
- Sections, in this order: `Code`, `Review`, `Other`. Include a section only
  when it has an entry.
- Indent with 4 spaces. Entry bullets sit under a section.
- Log only the work done: one line per entry, no sub-bullets or notes. I add
  notes myself.
- Each MR, issue, or work item entry is a Markdown link with its exact title,
  followed by a full stop. Get the title from GitLab
  (`glab orbit context mr:<iid>`, or `glab mr view`/`glab issue view`) — do
  not paraphrase it.
- Before you log an MR title, remove these annotations and the whitespace
  around them:
    - Draft prefixes: `Draft:`, `[Draft]`, `(Draft)`.
    - CI skip tags: `[ci skip]`, `[skip ci]`, anywhere in the title.

  Do not change other text in the title. Example:
  `Draft: Add webhook retries [ci skip]` becomes `Add webhook retries`.
- Link work items and issues as `https://gitlab.com/<project>/-/work_items/<iid>`
  and MRs as `https://gitlab.com/<project>/-/merge_requests/<iid>`.

## Which section

| Work | Section | Entry |
|---|---|---|
| Started on an issue or work item | Code | `Picked up [Title](url).` |
| Opened, pushed to, or fixed the pipeline of my own MR | Code | `[Title](url).` |
| Reviewed, re-reviewed, or commented on someone else's MR | Review | `[Title](url).` |
| Anything else (reading, meetings, admin, research) | Other | Plain sentence. |

## Steps

1. Run `date '+%-d %B %Y'` and build the heading.
2. Read `~/Desktop/work.md`. If it does not exist, create it.
3. Find today's heading. If absent, append it at the end of the file,
   preceded by a blank line.
4. Under today's heading, find or create the right section, keeping the
   `Code`, `Review`, `Other` order.
5. If the same link is already in that section today, do nothing. Otherwise
   append the entry at the end of the section.
6. Change only today's block. Never edit or reformat earlier days, or notes I
   have added.
7. Tell me in one line what was logged.

## When not to log

- Only questions, explanations, or exploration with no outcome.
- Work already logged with nothing new to add.
