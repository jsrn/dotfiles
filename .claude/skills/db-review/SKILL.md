---
name: db-review
description: Perform a GitLab database review of a merge request or the current branch. Use when asked to "db review", "database review", review migrations, review a ~database MR, or check schema/query changes against GitLab database guidelines. Covers migrations, structure.sql, db/docs dictionary, indexes, large-table limits, query plans, and batched background migrations.
argument-hint: "[mr-iid-or-url]"
allowed-tools: Bash(glab mr view:*), Bash(glab mr diff:*), Bash(glab ci get:*), Bash(glab ci trace:*), Bash(git fetch:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*)
---

# GitLab Database Review

Review database changes the way a `@gl-database` reviewer would. Work only from
evidence: the diff, the repo docs, the MR description, and the CI jobs. Never
approve on assumption.

## 1. Load context

Always read these first (paths relative to the gitlab repo root):

- `.ai/principles/distilled/database-fundamentals.md`
- `.ai/principles/distilled/database-migrations.md`
- `.ai/principles/distilled/database-schema.md`
- `.ai/principles/distilled/database-queries.md`
- `.ai/principles/distilled/testing-migrations.md` (if `spec/migrations` or migration code changed)
- `.ai/code-review.md`

Consult these on demand when the change touches the topic:

| Topic | Doc |
| --- | --- |
| Review checklist (SSOT) | `doc/development/database_review.md` |
| Migration style, timing, `disable_ddl_transaction!` | `doc/development/migration_style_guide.md` |
| Table size limits (50 GB index/FK, 100 GB column) | `doc/development/database/large_tables_limitations.md` |
| Indexes, async indexes, composite order | `doc/development/database/adding_database_indexes.md` |
| Foreign keys, loose foreign keys | `doc/development/database/foreign_keys.md`, `loose_foreign_keys.md` |
| Dropping columns / tables / downtime | `doc/development/database/avoiding_downtime_in_migrations.md` |
| Batched background migrations | `doc/development/database/batched_background_migrations.md` |
| NOT NULL, check constraints | `doc/development/database/not_null_constraints.md`, `check_constraints.md` |
| Column ordering | `doc/development/database/ordering_table_columns.md` |
| Multiple databases (main/ci/sec) | `doc/development/database/multiple_databases.md` |
| Partitioning | `doc/development/database/partitioning/` |
| Explain plans | `doc/development/database/understanding_explain_plans.md` |
| Query timing (100 ms rule) | `doc/development/database/query_performance.md` |
| Database dictionary | `doc/development/database/database_dictionary.md` |
| Cells sharding keys | `.ai/principles/distilled/cells-fundamentals.md` |

## 2. Gather the change

- Target: an MR URL or IID, or the current branch. For an MR, follow the
  `glab` skill to resolve it and read its description, diff, and discussions.
  For the current branch with no MR, `git fetch origin master` and use
  `git diff origin/master...HEAD`. Read the MR description in full.
- Classify every changed file: `db/migrate`, `db/post_migrate`,
  `db/structure.sql`, `db/schema_migrations`, `db/docs/*.yml`,
  `lib/gitlab/background_migration`, `spec/migrations`, models/finders/scopes,
  `db/fixtures/development`.
- For each touched table, read `db/docs/<table>.yml` and note `table_size`,
  `gitlab_schema`, `sharding_key`, and `feature_categories`.
- If there is an MR, check CI with the commands in the `glab` skill:
  - `glab ci get --merge-request <iid> -F json` for the status of
    `db:check-migrations`, `db:check-schema`,
    `db:gitlabcom-database-testing`, and `rubocop`.
  - `glab ci trace <job-id>` for any of those that failed.
  - `glab mr view <iid> --comments` for the database testing bot's comment,
    which has migration runtimes.

  Report any of those jobs that are missing, failing, or still running.

## 3. Checklist

Read `checklist.md` in this skill's directory and evaluate every item that
applies to the change.

## 4. Report

Follow `.ai/code-review.md` severity layers. Output, in this order:

1. **Verdict**: `Approve`, `Approve with nits`, or `Request changes`, and
   the one-line reason.
2. **Blockers**: numbered, each with `path:line`, the rule broken, the
   doc that states it, and the concrete fix.
3. **Improvements**: non-blocking, same format.
4. **Nitpicks**: labelled as such.
5. **Missing evidence**: anything the description or CI should have shown
   but did not (plans, timings, exception link, seed file, BBM comment).
6. **Checked and OK**: a short list of the risky areas you verified, so the
   author knows what was covered.

Rules:

- Cite the doc path for every blocker. Do not invent rules; if you cannot
  find it in the docs, mark it as a question.
- Ask for the author's Database Lab timing or plan rather than guessing
  production behaviour.
- If a finding is disputed or subtle, offer to demonstrate it with
  `/make-poc-spec`.
- Do not post to GitLab unless asked. If asked, follow the posting rules in
  the `glab` skill.
- Before posting, draft the prose with the `Agent` tool (`model: sonnet`),
  then check the draft against your findings before showing it to the user.
