---
name: work-log
description: Add an entry to my daily work log at ~/Desktop/work.md, and copy notable work to my brag document at ~/brag.md. Use at the start of a code review or re-review of an MR (as soon as the MR is known), after I finish other units of work in the session — posting review comments, opening or pushing to an MR, or picking up an issue or work item — and when I ask to "log this", "add to my work log", or "note this in work.md".
argument-hint: "[code|review|other] [note]"
allowed-tools: Read(~/Desktop/work.md), Edit(~/Desktop/work.md), Write(~/Desktop/work.md), Read(~/brag.md), Edit(~/brag.md), Write(~/brag.md), Bash(date:*), Bash(glab mr view:*), Bash(glab issue view:*), Bash(glab orbit context:*)
---

# Work log

Record what I did in `~/Desktop/work.md`, under today's date heading.

## File format

```markdown
# 19th November 2026

- Code:
    - Picked up [Explore archiving webhook logs to object storage](https://gitlab.com/gitlab-org/gitlab/-/work_items/605238).
    - Opened [Archive webhook logs to object storage](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268201).
    - Updated [Add webhook retries](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267980).
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
| Opened my own MR | Code | `Opened [Title](url).` |
| Pushed to, or fixed the pipeline of, my own existing MR | Code | `Updated [Title](url).` |
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
   append the entry at the end of the section. An MR opened today keeps its
   `Opened` entry when I push to it later.
6. Change only today's block. Never edit or reformat earlier days, or notes I
   have added.
7. Decide if the work belongs in the brag document (see below). If it does,
   add it to `~/brag.md`.
8. Tell me in one line what was logged, and what went to `~/brag.md`.

## Brag document

`~/brag.md` collects work worth citing in my performance review. Copy only
notable work there, not routine work. Most entries do not qualify.

Copy work that has one of these:

- Measurable impact: performance, reliability, cost, or scale improvements.
- Fixes for incidents, security issues, data loss, or customer-reported bugs.
- Large removal of risk or technical debt, or a hard problem solved.
- A review that found a serious bug or design problem before merge.
- Help or leadership outside my own work: unblocking another team,
  mentoring, docs or tooling that others use, starting an initiative.
- Anything else that seemed impressive.

Do not copy: small refactors, routine reviews, spec-only changes, admin.

### Operating principles

Tie each entry to the
[GitLab operating principles](https://handbook.gitlab.com/handbook/company/operating-principles/)
it shows. Tag it with the principle emoji, as the handbook asks:

| Emoji | Principle | Shown by work that… |
|---|---|---|
| ⚡ | Speed with Quality | Ships fast with high quality, proves work on GitLab first (customer zero), automates with agents, removes bureaucracy. |
| 🎯 | Ownership Mindset | Fixes a problem that was not mine ("never someone else's problem"), helps other teams, saves budget, people, or time. |
| 🤝 | Customer Outcomes | Changes something for customers: fixes their bug, unblocks them, improves what they use. |

Use only the principles the work clearly shows; one is enough. If the work
shows none, it probably does not belong in the brag document. Culture of
Excellence has no emoji; do not tag it.

Format:

```markdown
# Brag document

## November 2026

- 19th November: Opened [Archive webhook logs to object storage](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/268201). Moves old webhook logs out of PostgreSQL, so the table stops growing without limit. ⚡🎯
```

- One `## <full month> <year>` heading per month, oldest first. If the file
  does not exist, create it with the `# Brag document` heading.
- Entry: the date, the same link as the work log entry, one sentence on why
  it matters, then the principle emoji. Use only facts from the MR, issue, or this session. Do not
  invent or inflate impact; if the impact is unknown, describe what the work
  does.
- If the same link is already in `~/brag.md`, do nothing.
- Never edit or reformat existing entries.

## When not to log

- Only questions, explanations, or exploration with no outcome.
- Work already logged with nothing new to add.
