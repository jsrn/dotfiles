# Database review checklist

Evaluate every applicable item. Record a finding for each miss, with the file
and line.

The thresholds, IDs, and version numbers below are a snapshot of the docs.
If they disagree with the doc the SKILL.md table links for that topic, the
doc wins. Use the doc's value and mention that this checklist is out of date.

### Migrations (all types)

- Reversible: `change`, or an explicit `down`. Irreversible ones state why
  and how to recover data.
- Transaction model: either transactional, or `disable_ddl_transaction!`
  with only concurrent/`_concurrently` helpers. Never mix.
- Correct type: regular vs post-deploy vs batched background. Index adds,
  FK adds, and column drops on non-trivial tables belong in post-deploy.
- Timing: total per deploy under 1 h on GitLab.com; single transaction
  queries well under 15 s cumulative. Use `db:gitlabcom-database-testing`
  numbers when available.
- `db/structure.sql` changes match the migrations exactly; no stray diffs.
- `db/schema_migrations/<version>` file added/removed for each migration.
- `restrict_gitlab_migration gitlab_schema:` set correctly for data
  migrations; schema-only migrations do not set it.
- Milestone set (`milestone 'XX.Y'`) and matches the current release.
- Migration class inherits from the `Gitlab::Database::Migration[x.y]`
  version the migration style guide currently requires for new migrations.
- No RuboCop disables without justification.
- Lock retries: transactional by default; non-transactional migrations use
  `with_lock_retries` where appropriate.
- Spec present in `spec/migrations` for data migrations and anything
  non-trivial.

### Tables and columns

- New table: `db/docs/<table>.yml` present with description, owning
  feature category, `gitlab_schema`, `sharding_key` (or documented
  exemption), and `table_size: small`.
- Column ordering follows the size-alignment guideline.
- Text columns use `text` plus a limit (`add_text_limit`), never `string`.
- Timestamps are `timestamptz`, IDs are `bigint`.
- Every reference column has an FK (or a loose FK with `db/docs`
  `loose_foreign_keys` entry) and an index.
- New tables have a seed in `db/fixtures/development/`.
- Static/lookup data uses a fixed items model, not a table.
- MR description answers the growth and read/write questions for new
  tables.
- Column removal: column was `ignore_column`'d in a previous release with
  `remove_after`/`remove_with`.
- Large-table limits from `db/docs` `table_size`: no new index or FK column
  on tables at/over 50 GB, no new column at/over 100 GB, unless an approved
  exception is linked. `table_size: over_limit` is a hard stop.
- Siphon: adding a column to a Siphon-replicated table also updates the
  ClickHouse `siphon_*` table (see `clickhouse.md` principle).

### Indexes

- Added with `add_concurrent_index` (or partitioned helpers) and a name
  under 63 chars following the naming convention.
- Not redundant with an existing index; a new composite index removes the
  prefixes it supersedes.
- Dropping: no query still needs it; composite replacements have the right
  leading columns.
- Large table: Database Lab `CREATE INDEX CONCURRENTLY` timing in the MR
  description. Over 10 min goes to post-deploy; over 1 h goes async via
  `prepare_async_index`.
- Partial index predicates match the queries they serve.

### Constraints

- `NOT NULL` on existing columns uses the validate-later pattern
  (`add_not_null_constraint` then `validate_not_null_constraint` in a later
  migration) with a backfill in between.
- Check constraints and FKs on existing tables are added `validate: false`
  and validated in a separate post-deploy migration.

### Data migrations and batched background migrations

- Large tables always use BBM, never inline `update_all`.
- Batch/sub-batch sizes and intervals are sensible; batching column is
  indexed; `each_batch` uses a primary or unique key.
- Job class in `lib/gitlab/background_migration/` with a spec; queue
  migration in `db/post_migrate` with `restrict_gitlab_migration`.
- Finalize migration is scheduled per the BBM docs.
- Deletes carry `~data-deletion`, a recovery plan, and an affected-row
  count from a plan.
- Description states the user-facing impact if the migration is wrong.

### Queries (models, finders, scopes, services)

- Every new or changed query has raw SQL plus a postgres.ai explain link in
  the MR description, run against realistic IDs (gitlab-org 9970,
  gitlab-org/gitlab 278964, gitlab-qa user 1614863) returning non-zero rows.
- Plans stay under 100 ms; no seq scans on large tables; index used.
- Before/after plans for query changes.
- No N+1; `QueryRecorder` spec where loops touch the DB.
- Bulk ops (`update_all`, `delete_all`, `upsert_all`, `destroy_all`) are
  scoped and batched.
- Cross-database joins or transactions are avoided (main/ci/sec split);
  `allow_cross_joins_across_databases` only with an issue link.
- Keyset pagination for large result sets; `IN` with large lists uses the
  efficient in-operator pattern.
- Query comes from the code path actually executed (check `development.log`
  or the performance bar if in doubt).

