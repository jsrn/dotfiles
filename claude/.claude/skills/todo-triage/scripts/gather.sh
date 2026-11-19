#!/usr/bin/env bash
# Gather pending GitLab TODOs plus the context needed to triage them.
# Usage: gather.sh <out-dir>   -> writes <out-dir>/items.json (one entry per target)
set -euo pipefail

out=${1:?usage: gather.sh <out-dir>}
mkdir -p "$out"
me=$(glab api user | jq -r .username)

# --paginate concatenates JSON arrays; jq -s 'add' flattens them.
glab api --paginate "todos?state=pending&per_page=100" | jq -s 'add // []' > "$out/todos.json"

enc() { jq -rn --arg s "$1" '$s|@uri'; }

# Some endpoints 404 (fork pipelines, request-for-help issues). Fall back instead of aborting.
api_or() {
  local fallback=$1; shift
  local body
  if body=$(glab api "$@" 2>/dev/null) && jq -e . >/dev/null 2>&1 <<<"$body"; then
    jq -s 'if length > 1 then add else .[0] end' <<<"$body"
  else
    echo "$fallback"
  fi
}

jq -c 'group_by(.target_url | sub("#.*$"; "")) | .[]' "$out/todos.json" | while read -r group; do
  type=$(jq -r '.[0].target_type' <<<"$group")
  path=$(jq -r '.[0].project.path_with_namespace' <<<"$group")
  iid=$(jq -r '.[0].target.iid' <<<"$group")
  p=$(enc "$path")

  todos=$(jq '[.[] | {id, action: .action_name, author: .author.username, created: .created_at[0:16], body: .body[0:800]}]' <<<"$group")
  base=$(jq --argjson todos "$todos" '.[0] | {type: .target_type, project: .project.path_with_namespace, iid: .target.iid, title: .target.title, url: (.target_url | sub("#.*$"; "")), state: .target.state, todos: $todos}' <<<"$group")

  if [[ $type == MergeRequest ]]; then
    mr=$(glab api "projects/$p/merge_requests/$iid")
    reviewers=$(glab api "projects/$p/merge_requests/$iid/reviewers" | jq '[.[] | {user: .user.username, state}]')
    approvals=$(glab api "projects/$p/merge_requests/$iid/approvals" | jq '{approved_by: [.approved_by[].user.username], approvals_left}')
    versions=$(glab api "projects/$p/merge_requests/$iid/versions" | jq '{pushes: length, last_push: .[0].created_at[0:16]}')
    drafts=$(api_or null "projects/$p/merge_requests/$iid/draft_notes" | jq 'if . == null then null else length end')
    glab api --paginate "projects/$p/merge_requests/$iid/discussions?per_page=100" | jq -s 'add // []' > "$out/disc.json"
    diffs=$(api_or '[]' --paginate "projects/$p/merge_requests/$iid/diffs?per_page=100")

    ctx=$(jq -n \
      --argjson mr "$mr" --argjson reviewers "$reviewers" --argjson approvals "$approvals" \
      --argjson versions "$versions" --argjson drafts "$drafts" --argjson diffs "$diffs" \
      --slurpfile disc "$out/disc.json" --arg me "$me" '
      ($disc[0]) as $d |
      {
        author: $mr.author.username, draft: $mr.draft, labels: $mr.labels,
        milestone: $mr.milestone.title, milestone_due: $mr.milestone.due_date,
        created: $mr.created_at[0:10], description: ($mr.description // "")[0:1500],
        reviewers: $reviewers, approvals: $approvals, versions: $versions,
        my_draft_notes: $drafts,
        my_last_note: ([$d[].notes[] | select(.author.username == $me and (.system | not)) | .created_at[0:16]] | max),
        my_unresolved_threads: ([$d[] | select(.notes[0].author.username == $me and .notes[0].resolvable and (.notes[0].resolved | not))] | length),
        roulette_row: ([$d[].notes[] | select(.author.username == "gitlab-bot" and (.body | test("roulette"; "i"))) | .body | split("\n")[] | select(test("@" + $me + "\\b"))] | first),
        files: [$diffs[] | {path: (.new_path // .old_path), new: .new_file, deleted: .deleted_file,
                            added: ([.diff | split("\n")[] | select(startswith("+") and (startswith("+++") | not))] | length),
                            removed: ([.diff | split("\n")[] | select(startswith("-") and (startswith("---") | not))] | length)}]
      }')
  else
    # The request-for-help project 404s on issues/:iid, but notes work for every project.
    notes=$(glab api --paginate "projects/$p/issues/$iid/notes?sort=desc&per_page=50" | jq -s 'add // []')
    issue=$(api_or '{}' "projects/$p/issues/$iid")
    ctx=$(jq -n --argjson notes "$notes" --argjson issue "$issue" --arg me "$me" '{
        labels: $issue.labels, assignees: [($issue.assignees // [])[].username],
        recent_notes: [$notes[] | select(.system | not)][:6] | map({author: .author.username, at: .created_at[0:16], body: .body[0:500]}),
        recent_events: [$notes[] | select(.system)][:4] | map({author: .author.username, at: .created_at[0:16], body: .body[0:200]}),
        my_last_note: ([$notes[] | select(.author.username == $me and (.system | not)) | .created_at[0:16]] | max)
      }')
  fi

  jq -n --argjson base "$base" --argjson ctx "$ctx" '$base + {context: $ctx}'
done | jq -s --arg me "$me" '{me: $me, items: .}' > "$out/items.json"

rm -f "$out/disc.json"
jq -r '"\(.me): \(.items | length) items, \([.items[].todos[]] | length) todos -> '"$out"'/items.json"' "$out/items.json"
