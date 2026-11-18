---
name: watch-pipeline
description: Watch a GitLab merge request's latest pipeline on a schedule and notify me when it finishes. Use when asked to "watch the pipeline", "let me know when CI finishes", "check the pipeline every N minutes", "ping me when the MR pipeline is done", or "keep an eye on" an MR's CI — including security-mirror MRs in gitlab-org/security/*. Read-only.
argument-hint: <mr-url | group/project!iid> [interval-minutes]
allowed-tools: Bash(*/watch-pipeline/scripts/pipeline_status.sh:*), Bash(glab api:*), Bash(date:*)
---

# Watch pipeline

Poll an MR's latest pipeline, stay quiet while it runs, and send one
notification when it finishes. Never post comments, retry jobs, cancel
pipelines or push. The user asked to be told, not for action.

## 1. Resolve the input

- MR URL or `group/project!iid`: use as given.
- Bare IID (`7254`, `!7254`): use the current checkout's project
  (`glab repo view -F json | jq -r .full_path`). Security MRs live in a
  different project (`gitlab-org/security/gitlab`), so if the IID could be
  either, ask.
- Interval: default 5 minutes. Accept a number of minutes from the arguments.

## 2. Check once now

Run the status script. Its path is `scripts/pipeline_status.sh` under this
skill's base directory. Use the absolute path, because the cron prompt in
step 3 runs without the skill loaded.

```
<base-dir>/scripts/pipeline_status.sh <mr-ref>
```

It prints JSON: `pipeline` (id, status, web_url), `finished`, parent
`jobs` (status counts and failed jobs without `danger-review`), and
`bridges` (each downstream pipeline with its own job counts and failures).
One call takes about 20–30 seconds on a full GitLab pipeline.

- `pipeline` is null: say the MR has no pipeline and stop.
- `finished` is true: report as in step 4 and stop. Do not schedule.
- Otherwise: report one line and go on to step 3.

## 3. Schedule the checks

Run `date` to get the local time. Then call `CronCreate` with
`recurring: true` and an off-minute cron, for example `2-59/5 * * * *` for
5 minutes. Off-minutes stop all users' jobs from firing at the same moment.

The prompt fires later as a new turn, without this skill. Make it
self-contained. Fill in this template:

```
Pipeline watch for <mr-ref> (<mr-url>). Read-only: do not post comments, push, retry or cancel jobs.
1. Run: <absolute-path>/scripts/pipeline_status.sh '<mr-ref>'
2. If "finished" is false: reply with one line only (pipeline id+link, status, parent passed/failed counts, which bridge pipelines are still running). Do NOT notify. If the pipeline id differs from <first-pipeline-id>, say a new pipeline started.
3. If "finished" is true: send PushNotification "<short-ref> pipeline <id>: <status>, <n> blocking failures (<m> allowed)". Then CronList, find this pipeline-watch job for <mr-ref>, CronDelete it. Report: status with link, each downstream pipeline status, failed jobs grouped as blocking (allow_failure false) and allowed, with job links. End with a `result:` line.
```

Tell the user: the job ID, the first run time from the `CronCreate`
result (not the cron expression, because the scheduler adds jitter), and
these limits:

- The job lives only in this session. If the session closes, the watch stops.
- Recurring jobs expire after 7 days.
- A phone push needs Remote Control. Without it, only the desktop gets the
  notification.

## 4. Report a finished pipeline

- Status, pipeline link, SHA (short).
- Each downstream pipeline with its status and link. Skipped bridges have
  no downstream pipeline, so say "skipped".
- Failed jobs, split into **blocking** (`allow_failure: false`) and
  **allowed to fail**, with links. Say which pipeline each is in.

Why split them: a parent pipeline can show `success` with failed jobs, and
`failed` usually comes from one blocking job. The user needs to see which
jobs matter at a glance.

## Notes

- The parent pipeline stays `running` until every bridge finishes, even
  when no parent job is still running. The e2e omnibus bridge is often the
  last one. Name the bridge that blocks progress in each running line, so
  the user knows why the pipeline is not done.
- A bridge can show `pending` while its downstream pipeline is `running`.
  Report the downstream status.
- The script always reads the latest MR pipeline. After a new push, it
  follows the new pipeline.
- To stop early: `CronList`, then `CronDelete <id>`.
