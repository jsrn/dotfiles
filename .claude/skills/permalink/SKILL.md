---
name: permalink
description: Build a permanent GitLab or GitHub URL to a file, or a line range in a file, pinned to a full commit SHA. Use when the user asks for a "permalink", "link to these lines", "reference on GitLab.com", "URL for this file at this commit", or wants to share a code location that will not drift as the branch moves.
argument-hint: "<path>[:<start>[-<end>]] [ref]"
allowed-tools: Bash(git rev-parse:*), Bash(git remote get-url:*), Bash(git show:*), Bash(git ls-files:*), Bash(git branch -r --contains:*), Bash(pbcopy)
---

# Permalink to file lines at a commit

Produce a URL of the form

```
https://<host>/<namespace>/<project>/-/blob/<full-sha>/<path>#L<start>-<end>     # GitLab
https://github.com/<owner>/<repo>/blob/<full-sha>/<path>#L<start>-L<end>         # GitHub
```

Always use the **full 40-character SHA**, never a short SHA or a branch name.
Branch names drift; short SHAs can become ambiguous.

## Steps

1. **Resolve the commit.** Default to the current branch HEAD unless the user
   names a ref.

   ```
   git rev-parse HEAD            # or: git rev-parse <ref>
   ```

2. **Resolve the host and project** from the remote. Prefer `origin`; if the
   user is working in a fork, ask which remote they mean only if the two point
   at different projects and the choice matters.

   ```
   git remote get-url origin
   ```

   Normalise every remote form to `https://<host>/<path>`:
   - `git@gitlab.com:gitlab-org/gitlab.git` → `https://gitlab.com/gitlab-org/gitlab`
   - `ssh://git@gitlab.example.com:2222/group/sub/project.git` → `https://gitlab.example.com/group/sub/project`
   - `https://github.com/owner/repo.git` → `https://github.com/owner/repo`
   - `https://user@gitlab.com/group/project` → `https://gitlab.com/group/project`

   Strip a trailing `.git`, any `user@` prefix, and any SSH port. The web UI
   does not use the SSH port. Nested GitLab groups are fine; keep every path
   segment. A host that isn't `github.com` is a GitLab instance (gitlab.com or
   self-managed) unless the user says otherwise.

   Make the file path relative to the repo root, not the current directory:

   ```
   git ls-files --full-name <path>
   ```

3. **Find the lines.** If the user gives a symbol, block, or description instead
   of numbers, locate it at that commit, not in the working tree:

   ```
   git show <sha>:<path> | grep -n '<pattern>'
   ```

   Use `git show <sha>:<path> | sed -n '<start>,<end>p'` to confirm the range
   covers exactly the intended block, including its closing line.

4. **Assemble the URL.**

   | Target | GitLab anchor | GitHub anchor |
   |---|---|---|
   | whole file | none | none |
   | one line | `#L12` | `#L12` |
   | range | `#L9-13` | `#L9-L13` |

   GitLab path uses `/-/blob/`; GitHub uses `/blob/`.

   Percent-encode characters in the file path that are not URL-safe, such as
   space → `%20` and `#` → `%23`. Leave `/` as is.

5. **Check the commit is reachable on the remote.** The link only resolves once
   the commit has been pushed.

   ```
   git branch -r --contains <sha>
   ```

   This only checks remote-tracking refs as of the last fetch. It is a best
   guess, not proof. It also misses commits that exist only on MR refs, which
   still resolve on GitLab. If it prints nothing, say the commit may not be
   pushed and the link may 404 until it is. Do not push or fetch on the
   user's behalf.

## Output

Give the bare URL on its own line so it can be copied. Follow it with the
quoted lines in a fenced block so the reader can confirm the range is right
without opening the link. Mention the unpushed-commit caveat only when it
applies.

For a single URL, also copy it to the clipboard with `printf '%s' '<url>' | pbcopy`
and say that you did.

Example:

```
https://gitlab.com/gitlab-org/gitlab/-/blob/c1950c786d2e3f8dc672989eb9a5d32419f9de0c/config/events/click_search_blob_result_line.yml#L9-13
```

```yaml
additional_properties:
  value:
    description: Position of the result.
  property:
    description: Line number.
```

## Variants

- **Multiple locations**: one URL per location, each with its own quoted block.
- **Blame or raw view**: swap `blob` for `blame` or `raw` on GitLab, `blame` or
  `raw` on GitHub, if the user asks for it.
- **Diff or MR context**: this skill is for file permalinks. If the user wants a
  link to a diff line in a merge request, say so and point them at the MR
  changes tab instead.
