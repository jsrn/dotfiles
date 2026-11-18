#!/usr/bin/env bash
# Usage: pipeline_status.sh <mr-url | group/project!iid>
# Prints one JSON summary of the MR's latest pipeline and its downstream pipelines.
# Read-only: uses GET requests through `glab api` only.
set -euo pipefail

input="${1:?usage: pipeline_status.sh <mr-url | group/project!iid>}"

if [[ "$input" =~ ^https?://[^/]+/(.+)/-/merge_requests/([0-9]+) ]]; then
  path="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[2]}"
elif [[ "$input" =~ ^(.+)!([0-9]+)$ ]]; then
  path="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[2]}"
else
  echo "cannot parse MR reference: $input" >&2; exit 2
fi

project="${path//\//%2F}"

# Jobs endpoints return at most 100 per page; big pipelines have several hundred.
jobs() { glab api --paginate "projects/$1/pipelines/$2/jobs?per_page=100" | jq -s 'add // []'; }

job_summary='{
  counts: (group_by(.status) | map({(.[0].status): length}) | add // {}),
  failed: [ .[] | select(.status == "failed" and .name != "danger-review")
            | {name, allow_failure, web_url} ]
}'

pipeline=$(glab api "projects/$project/merge_requests/$iid/pipelines?per_page=1" | jq '.[0] // empty')
if [[ -z "$pipeline" ]]; then
  jq -n --arg path "$path" --arg iid "$iid" '{mr: "\($path)!\($iid)", pipeline: null}'
  exit 0
fi

pid=$(jq -r .id <<<"$pipeline")
parent_jobs=$(jobs "$project" "$pid" | jq "$job_summary")

bridges='[]'
while IFS= read -r bridge; do
  ds_id=$(jq -r '.downstream_pipeline.id // empty' <<<"$bridge")
  ds_project=$(jq -r '.downstream_pipeline.project_id // empty' <<<"$bridge")
  ds_jobs='null'
  if [[ -n "$ds_id" ]]; then
    ds_jobs=$(jobs "$ds_project" "$ds_id" | jq "$job_summary")
  fi
  bridges=$(jq --argjson b "$bridge" --argjson j "$ds_jobs" \
    '. + [{name: $b.name, status: $b.status,
           downstream: ($b.downstream_pipeline | if . then {id, status, web_url} else null end),
           jobs: $j}]' <<<"$bridges")
done < <(glab api --paginate "projects/$project/pipelines/$pid/bridges?per_page=100" | jq -c -s 'add // [] | .[]')

jq -n --arg path "$path" --arg iid "$iid" \
  --argjson p "$pipeline" --argjson jobs "$parent_jobs" --argjson bridges "$bridges" '{
  mr: "\($path)!\($iid)",
  pipeline: ($p | {id, status, web_url, sha, created_at}),
  finished: ($p.status | IN("success", "failed", "canceled", "skipped", "manual")),
  jobs: $jobs,
  bridges: $bridges
}'
