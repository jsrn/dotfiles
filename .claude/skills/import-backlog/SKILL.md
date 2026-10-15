---
name: import-backlog
description: Search the GitLab Import team's backlog (group::import) for issues about a topic. Use when asked "do we have any issues about X", whether an import bug or feature request "already has an issue", or to find duplicates in the import backlog.
argument-hint: <topic or keywords>
allowed-tools: Bash(glab api:*), Bash(glab issue view:*), Bash(jq:*)
---

# Import backlog search

Find existing issues owned by the Import team that match a topic, error, or
feature request.

## Scope

- The backlog is every issue labelled `group::import` in the `gitlab-org`
  group. Most are in `gitlab-org/gitlab`, but query the group so issues in
  other projects are included.
- Filter on `group::import` only. Don't narrow by `Importer:*` or
  `Category:*` labels, because they aren't applied reliably.

If `group::import` returns nothing, the label may have been renamed. Check
with `glab api "groups/gitlab-org/labels?search=import"`.

## Querying

Use the group issues API. URL-encode spaces as `%20`. This `glab` has no
`--jq` flag, so pipe to `jq`.

```
glab api "groups/gitlab-org/issues?labels=group::import&state=all&search=<words>&in=title,description&per_page=100" \
  | jq -r '.[] | [.references.full, .state, .title, (.labels|join(",")), .updated_at, .web_url] | @tsv'
```

- `search` ANDs every word, so keep each query short. Matches are loose
  (a word anywhere in a long description counts), so judge each result.
- Skip the automated triage reports in `gitlab-org/quality/triage-reports`.

Read an issue in full with `glab issue view <iid> -R <project> --comments`.

## Steps

1. Turn the topic into 2–4 short queries. Use distinct words, synonyms, and
   any error class or message the user gave. For example, "GitHub rate limit"
   becomes `rate limit`, `RateLimitError`, `429`, and `throttl`.
   If the topic names an importer, add its name as a search word (`github
   rate limit`) rather than filtering by label.
2. Include closed issues (`state=all`). A closed duplicate or a "won't do"
   decision answers the question.
3. Remove duplicate results. Read the title and description of the best
   matches. Rank by how closely they match, not by how recently they were
   updated.
4. If nothing matches, say so plainly and list the queries you ran.

## Report

Start with a one-line answer: yes (and the best match), or no.

Then a table of matches, best first, at most 10 rows:

| Issue | State | Title | Notes |
| --- | --- | --- | --- |
| [gitlab#633091](url) | open | GitHub sync: deleted comments not deleted | Exact match |

- Link each issue with its `web_url`.
- For closed issues, say how they were closed (fixed, duplicate, won't do).
- Mark issues that only partly match, and say what they leave out.

Read only. Never comment on, label, or close an issue unless the user asks.
