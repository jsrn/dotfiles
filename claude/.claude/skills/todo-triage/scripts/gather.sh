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
  base=$(jq --argjson todos "$todos" '.[0] | {type: .target_type, project: .project.path_with_namespace, group: .group.full_path, iid: .target.iid, title: .target.title, url: (.target_url | sub("#.*$"; "")), state: .target.state, todos: $todos}' <<<"$group")

  # Group-level work items (epics) have no project and no REST issues endpoint; read them separately.
  if [[ $path == null ]]; then
    ctx='{"group_work_item": true}'
  elif [[ $type == MergeRequest ]]; then
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

# Taskwarrior: the filter must come before `export` (Taskwarrior 3 reads a later word as a report name).
task project:work status:pending export > "$out/tasks_raw.json"
url_re='https://gitlab\.com/[^[:space:])>]+/-/(merge_requests|issues|work_items)/[0-9]+(#note_[0-9]+)?'

jq --arg re "$url_re" '
  ([.[].uuid]) as $pending |
  map({uuid, description, project, due, scheduled, priority, urgency,
       tags: (.tags // []), annotations: [.annotations[]?.description],
       blocked: ([(.depends // [])[] | select(IN($pending[]))] | length > 0),
       links: ([[.description, .annotations[]?.description][] | match($re; "g").string] | unique)})
' "$out/tasks_raw.json" > "$out/tasks.json"

# target -> {state, title}; group-level work items have no REST endpoint, so they stay unchecked.
link_info() {
  local url=${1%%#*} rest path kind iid
  rest=${url#https://gitlab.com/}; path=${rest%%/-/*}; kind=$(cut -d/ -f1 <<<"${rest#*/-/}"); iid=${url##*/}
  [[ $path == groups/* ]] && { echo '{"state": null, "title": null, "checked": false}'; return; }
  local ep=issues; [[ $kind == merge_requests ]] && ep=merge_requests
  api_or '{}' "projects/$(enc "$path")/$ep/$iid" | jq '{state, title, checked: (.state != null)}'
}

# Non-system notes by others after the anchor note, for +await tasks.
replies_after() {
  local url=$1 rest path kind iid anchor ep=issues
  rest=${url#https://gitlab.com/}; path=${rest%%/-/*}; kind=$(cut -d/ -f1 <<<"${rest#*/-/}")
  iid=${url%%#*}; iid=${iid##*/}; anchor=${url##*#note_}
  [[ $kind == merge_requests ]] && ep=merge_requests
  api_or '[]' --paginate "projects/$(enc "$path")/$ep/$iid/notes?sort=asc&order_by=created_at&per_page=100" |
    jq --arg me "$me" --argjson anchor "$anchor" '
      (map(select(.id == $anchor)) | first | .created_at) as $at |
      if $at == null then {anchor_found: false, replies: []}
      else {anchor_found: true, anchor_at: $at[0:16],
            replies: [.[] | select((.system | not) and .created_at > $at and .author.username != $me)
                      | {author: .author.username, at: .created_at[0:16], body: .body[0:500]}]}
      end'
}

jq -r '[.[].links[] | sub("#.*$"; "")] | unique[]' "$out/tasks.json" | while read -r u; do
  jq -n --arg u "$u" --argjson i "$(link_info "$u")" '{($u): $i}'
done | jq -s 'add // {}' > "$out/link_state.json"

jq -r '.[] | select(.tags | index("await")) | .uuid as $id | [.links[] | select(test("#note_"))] | last // empty | "\($id) \(.)"' "$out/tasks.json" |
while read -r id u; do
  jq -n --arg id "$id" --arg u "$u" --argjson r "$(replies_after "$u")" '{($id): ({anchor: $u} + $r)}'
done | jq -s 'add // {}' > "$out/await.json"

jq --slurpfile ls "$out/link_state.json" --slurpfile aw "$out/await.json" '
  map(. + {links: [.links[] as $l | {url: $l} + ($ls[0][$l | sub("#.*$"; "")] // {})],
           await: ($aw[0][.uuid] // null)})
' "$out/tasks.json" > "$out/tasks.json.tmp" && mv "$out/tasks.json.tmp" "$out/tasks.json"
rm -f "$out/tasks_raw.json" "$out/link_state.json" "$out/await.json"
jq -r '"\(length) work tasks (\([.[] | select(.blocked)] | length) blocked, \([.[] | select(.await)] | length) awaiting a reply) -> '"$out"'/tasks.json"' "$out/tasks.json"
