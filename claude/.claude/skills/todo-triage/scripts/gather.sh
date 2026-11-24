#!/usr/bin/env bash
# Gather pending GitLab TODOs and Taskwarrior work tasks, plus the context needed to triage them.
# Usage: gather.sh <out-dir>
#   -> <out-dir>/items.json  one entry per GitLab target: every TODO target, and every open target a task links to
#   -> <out-dir>/tasks.json  pending work tasks with their links, blocked flag and +await replies
set -euo pipefail

out=${1:?usage: gather.sh <out-dir>}
mkdir -p "$out"
me=$(glab api user | jq -r .username)

# --paginate concatenates JSON arrays; jq -s 'add' flattens them.
glab api --paginate "todos?state=pending&per_page=100" | jq -s 'add // []' > "$out/todos.json"

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

# One target per MR or issue, keyed the same way for TODOs and task links (work_items and issues URLs match).
jq -n --slurpfile todos "$out/todos.json" --slurpfile tasks "$out/tasks.json" '
  def key: "\(.type):\(.path):\(.iid)";
  def parse: capture("^https://gitlab\\.com/(?<path>.+?)/-/(?<kind>merge_requests|issues|work_items)/(?<iid>[0-9]+)")
             | {path, iid: (.iid | tonumber), type: (if .kind == "merge_requests" then "MergeRequest" else "Issue" end)};
  ([$todos[0] | group_by(.target_url | sub("#.*$"; ""))[] |
     {type: .[0].target_type, iid: .[0].target.iid,
      path: (.[0].project.path_with_namespace // ("groups/" + .[0].group.full_path)),
      url: (.[0].target_url | sub("#.*$"; "")), title: .[0].target.title, state: .[0].target.state,
      todos: [.[] | {id, action: .action_name, author: .author.username, created: .created_at[0:16], body: .body[0:800]}]}]) as $t |
  ([$tasks[0][] | .uuid as $u | .links[] | (parse + {url: sub("#.*$"; ""), task: $u})]) as $l |
  ($t + [$l[] | del(.task) + {todos: []}]) | group_by(key) |
  map((map(select(.todos | length > 0)) | first) // .[0]) |
  map(key as $k | . + {key: $k, tasks: [$l[] | select(key == $k) | .task] | unique})
' > "$out/targets.json"

mr_context() {
  local p=$1 iid=$2 mr=$3 reviewers approvals versions drafts diffs
  reviewers=$(glab api "projects/$p/merge_requests/$iid/reviewers" | jq '[.[] | {user: .user.username, state}]')
  approvals=$(glab api "projects/$p/merge_requests/$iid/approvals" | jq '{approved_by: [.approved_by[].user.username], approvals_left}')
  versions=$(glab api "projects/$p/merge_requests/$iid/versions" | jq '{pushes: length, last_push: .[0].created_at[0:16]}')
  drafts=$(api_or null "projects/$p/merge_requests/$iid/draft_notes" | jq 'if . == null then null else length end')
  glab api --paginate "projects/$p/merge_requests/$iid/discussions?per_page=100" | jq -s 'add // []' > "$out/disc.json"
  diffs=$(api_or '[]' --paginate "projects/$p/merge_requests/$iid/diffs?per_page=100")

  jq -n \
    --argjson mr "$mr" --argjson reviewers "$reviewers" --argjson approvals "$approvals" \
    --argjson versions "$versions" --argjson drafts "$drafts" --argjson diffs "$diffs" \
    --slurpfile disc "$out/disc.json" --arg me "$me" '
    ($disc[0]) as $d |
    {
      author: $mr.author.username, draft: $mr.draft, labels: $mr.labels,
      milestone: $mr.milestone.title, milestone_due: $mr.milestone.due_date,
      created: $mr.created_at[0:10], description: ($mr.description // "")[0:1500],
      reviewers: $reviewers, i_am_reviewer: ([$reviewers[].user] | index($me) != null),
      approvals: $approvals, versions: $versions,
      my_draft_notes: $drafts,
      my_last_note: ([$d[].notes[] | select(.author.username == $me and (.system | not)) | .created_at[0:16]] | max),
      my_unresolved_threads: ([$d[] | select(.notes[0].author.username == $me and .notes[0].resolvable and (.notes[0].resolved | not))] | length),
      roulette_row: ([$d[].notes[] | select(.author.username == "gitlab-bot" and (.body | test("roulette"; "i"))) | .body | split("\n")[] | select(test("@" + $me + "\\b"))] | first),
      files: [$diffs[] | {path: (.new_path // .old_path), new: .new_file, deleted: .deleted_file,
                          added: ([.diff | split("\n")[] | select(startswith("+") and (startswith("+++") | not))] | length),
                          removed: ([.diff | split("\n")[] | select(startswith("-") and (startswith("---") | not))] | length)}]
    }'
}

issue_context() {
  local p=$1 iid=$2 issue=$3 notes
  # The request-for-help project 404s on issues/:iid, but notes work for every project.
  notes=$(glab api --paginate "projects/$p/issues/$iid/notes?sort=desc&per_page=50" | jq -s 'add // []')
  jq -n --argjson notes "$notes" --argjson issue "$issue" --arg me "$me" '{
      labels: $issue.labels, assignees: [($issue.assignees // [])[].username],
      recent_notes: [$notes[] | select(.system | not)][:6] | map({author: .author.username, at: .created_at[0:16], body: .body[0:500]}),
      recent_events: [$notes[] | select(.system)][:4] | map({author: .author.username, at: .created_at[0:16], body: .body[0:200]}),
      my_last_note: ([$notes[] | select(.author.username == $me and (.system | not)) | .created_at[0:16]] | max)
    }'
}

jq -c '.[]' "$out/targets.json" | while read -r t; do
  type=$(jq -r .type <<<"$t"); path=$(jq -r .path <<<"$t"); iid=$(jq -r .iid <<<"$t")
  has_todos=$(jq '.todos | length > 0' <<<"$t")
  p=$(enc "$path")

  # Group-level work items (epics) have no REST issues endpoint; read them separately.
  if [[ $path == groups/* ]]; then
    jq '. + {context: {group_work_item: true}}' <<<"$t"; continue
  fi

  if [[ $type == MergeRequest ]]; then
    obj=$(api_or '{}' "projects/$p/merge_requests/$iid")
  else
    obj=$(api_or '{}' "projects/$p/issues/$iid")
  fi
  # A TODO's own target fields are kept; task-only targets take title and state from the API.
  t=$(jq --argjson o "$obj" '. + {title: (.title // $o.title), state: ($o.state // .state)}' <<<"$t")

  # Task-only targets that are merged or closed need no more context: their tasks go to Mark done.
  if [[ $has_todos == false && $(jq -r .state <<<"$t") != opened ]]; then
    jq '. + {context: null}' <<<"$t"; continue
  fi

  if [[ $type == MergeRequest ]]; then
    ctx=$(mr_context "$p" "$iid" "$obj")
  else
    ctx=$(issue_context "$p" "$iid" "$obj")
  fi
  jq --argjson ctx "$ctx" '. + {context: $ctx}' <<<"$t"
done | jq -s --arg me "$me" '{me: $me, items: .}' > "$out/items.json"

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

jq -r '.[] | select(.tags | index("await")) | .uuid as $id | [.links[] | select(test("#note_"))] | last // empty | "\($id) \(.)"' "$out/tasks.json" |
while read -r id u; do
  jq -n --arg id "$id" --arg u "$u" --argjson r "$(replies_after "$u")" '{($id): ({anchor: $u} + $r)}'
done | jq -s 'add // {}' > "$out/await.json"

# Give each task link the state of its target, and each task its +await replies.
jq --slurpfile items "$out/items.json" --slurpfile aw "$out/await.json" '
  def parse: capture("^https://gitlab\\.com/(?<path>.+?)/-/(?<kind>merge_requests|issues|work_items)/(?<iid>[0-9]+)")
             | "\(if .kind == "merge_requests" then "MergeRequest" else "Issue" end):\(.path):\(.iid)";
  ($items[0].items | map({key, value: {target: .url, state, title, checked: (.path | startswith("groups/") | not)}}) | from_entries) as $s |
  map(.uuid as $id | . + {
      links: [.links[] | {url: .} + ($s[parse] // {})],
      await: ($aw[0][$id] // null)})
' "$out/tasks.json" > "$out/tasks.json.tmp" && mv "$out/tasks.json.tmp" "$out/tasks.json"

rm -f "$out/disc.json" "$out/tasks_raw.json" "$out/targets.json" "$out/await.json"
jq -r '"\(.me): \(.items | length) items (\([.items[] | select(.todos | length > 0)] | length) with TODOs), \([.items[].todos[]] | length) todos -> '"$out"'/items.json"' "$out/items.json"
jq -r '"\(length) work tasks (\([.[] | select(.blocked)] | length) blocked, \([.[] | select(.await)] | length) awaiting a reply) -> '"$out"'/tasks.json"' "$out/tasks.json"
