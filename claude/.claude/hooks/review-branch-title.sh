#!/usr/bin/env bash
# UserPromptSubmit hook: on "/review-branch [level] <mr>", title the session "Review: <MR title>".
set -uo pipefail

prompt=$(jq -r '.prompt // ""')
[[ $prompt =~ ^[[:space:]]*/review-branch[[:space:]]+(.*)$ ]] || exit 0

mr=""
for arg in ${BASH_REMATCH[1]}; do
  case $arg in
    low|medium|high|xhigh|max) ;;
    *) mr=$arg; break ;;
  esac
done
[[ -n $mr ]] || exit 0

title=$(glab mr view "$mr" -F json 2>/dev/null | jq -r '.title // empty')
[[ -n $title ]] || title="!${mr##*/}"

jq -n --arg t "Review: $title" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
