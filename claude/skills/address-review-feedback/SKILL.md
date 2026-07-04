---
name: address-review-feedback
description: Address reviewer feedback and CI failures on the current branch's PR, one item at a time, with fixes squashed into the correct commit and courteous replies drafted for approval before posting. Use when the user says "address review comments", "handle review feedback", "fix PR comments", or "fix CI failures".
compatibility:
  note: "Requires gh CLI (authenticated) and mvnd installed on the host system."
tags:
  - pr
  - review
  - ci
  - git
  - workflow
---

# Address Reviewer Feedback

Interactive workflow for addressing reviewer feedback and CI failures on the PR
for the current branch. Work through items one at a time; pause for approval on
non-mechanical changes, and always before posting replies or resolving threads.

## Prerequisites

- `gh` CLI authenticated (`gh auth status`) with access to the target repo
- `mvnd` installed and on `$PATH`

## Phase 1 — Gather (run once, upfront)

1. **Find the PR.** `gh pr list --head "$(git rev-parse --abbrev-ref HEAD)" --json number,url,headRepositoryOwner,headRepository,baseRefName`. If none, stop. Use `baseRefName` as `PR_BASE`; the PR's commit range is `origin/$PR_BASE..HEAD` (not always master).
2. **Fetch unresolved review threads** via GraphQL (threads, not raw comments, so resolution state is known):
   ```graphql
   query { repository(owner: "OWNER", name: "REPO") {
     pullRequest(number: 123) {
       reviewThreads(first: 100) {
         pageInfo { hasNextPage endCursor }
         nodes { id isResolved path line startLine originalLine originalStartLine diffHunk
           comments(first: 100) { pageInfo { hasNextPage endCursor }
             nodes { databaseId body author { login } commit { oid } originalCommit { oid } } } } } } } }
   ```
   Keep only threads with `isResolved = false`. Paginate separately: if `reviewThreads.pageInfo.hasNextPage`, re-query with `reviewThreads(first: 100, after: "<cursor>")`; if any thread's `comments.pageInfo.hasNextPage`, fetch the remaining comments with a per-thread `comments(first: 100, after: "<cursor>")` query.
3. **Fetch CI status.** Use `gh pr checks <PR_NUM>` — PR-scoped, unlike `gh run list --branch` which includes unrelated workflows. For each failed check, the `link` URL ends in `/job/<job_id>`; fetch the log from that id:
   ```
   gh pr checks <PR_NUM> --json name,bucket,link --jq '.[] | select(.bucket == "fail") | .link'
   gh api repos/OWNER/REPO/actions/jobs/<job_id>/logs
   ```
   Extract error lines. If a check's head SHA ≠ `git rev-parse HEAD`, flag at the top of the agenda that failures may be stale.
4. **Map each item to a target commit.** For review comments, if the first comment's `commit.oid` (or `originalCommit.oid`) is in `origin/$PR_BASE..HEAD`, use it directly; otherwise `git blame` the referenced file:line. For CI failures, blame the failing code the same way. Items that don't touch branch commits (e.g. flake in base code) get flagged separately.
5. **Group items by target commit.** Present the agenda to the user:
   ```
   Commit <sha1> <subject>
     [R1] review thread at path:line — <one-line summary>
     [R2] …
   Commit <sha2> <subject>
     [C1] CI test failure: <test name> — <one-line error>
   Unassigned
     [X1] <item>
   ```
   For thread location, use `line` → `startLine` → `originalLine` → `originalStartLine`. If all are null (outdated thread after force-push), flag the item as "outdated — needs manual review" rather than dropping it.

   Do **not** start fixing yet. This is an agenda for the user to see the scope.

## Phase 2 — Per-item loop (one at a time)

Iterate oldest-commit-first, one item per iteration. For each item:

### 2a. Assess

Show **only this item**:
- The comment body (or CI error)
- The referenced code (read the file at the referenced line, include 5 lines of context)
- **Verdict**: `stale` (code gone/changed), `actionable`, or `needs-discussion`
- **Proposed fix** in 1–3 sentences, or why you think it should be skipped/pushed back
- **Target commit** (sha + subject)
- **Blast radius** — just this file? Does the fix touch other commits in the stack?

Pause. Wait for user feedback.

### 2b. Decide

Mechanical items (fix fully determined by a verify-step failure — compile, checkstyle, error-prone) skip the approval gate. Show the 2a assessment so the user can interrupt, then go straight to 2c. If the fix re-fails verify, fall back to approval.

Other items: user picks `apply` / `skip` / `push-back with reason` / `modify approach` / `mark stale`.

For CI failures, skip 2d-2f (no reviewer to reply to, no thread to resolve). If the failure looks like a flake, surface that assessment and let the user decide whether to skip vs investigate.

### 2c. If applying a fix

1. **Save downstream commits.**
   ```
   PATCH_DIR="/tmp/review-feedback-patches-$$"
   rm -rf "$PATCH_DIR" && mkdir -p "$PATCH_DIR"
   git format-patch <target_commit>..HEAD -o "$PATCH_DIR"
   ```
2. **Rewind to target commit.** First verify a clean tree: `git status --porcelain`. If non-empty, stop and ask the user to stash or commit their WIP. Otherwise, `git reset --hard <target_commit>`.
3. **Make the fix.** Use Edit/Write as normal.
4. **Verify compile + checks.**
   ```
   mvnd clean test-compile -DskipTests -P errorprone-compiler -pl <target_module> > /tmp/build-<sha>.log 2>&1
   tail -40 /tmp/build-<sha>.log
   ```
   `test-compile` runs `validate` (checkstyle, license, sortpom); `clean` prevents stale false greens. Add `-am` only if deps changed. If it fails, fix and re-run before amending.
5. **Re-read the commit message.** Stage the fix (`git add`), then compare the message against `git diff --cached HEAD~1` (what the amended commit will contain). If it no longer fits: draft an update, get approval, amend with the new message. Otherwise, `git commit --amend --no-edit`.
6. **Re-apply downstream patches.** For each saved patch in order: `git apply --index --3way <patch>` (stages on clean apply) → resolve any conflicts and `git add` them (ask user if non-trivial) → `git commit -C <original-sha>` (preserves original message).
7. **Verify each downstream commit still compiles.** CI runs `check-commit` per-commit, so each must build standalone. Walk the stack non-interactively:
   ```
   ORIG="$(git branch --show-current)"
   for sha in $(git rev-list --reverse <target_commit>..HEAD); do
     git checkout --detach "$sha" && <step 4 verify command>
   done
   git switch "$ORIG"
   ```
8. **For downstream commits whose diff materially changed** (patch conflicts required surgery), re-check their commit messages the same way as step 5.

### 2d. Draft reviewer reply

Write a short, courteous reply addressed to a human reader:
- Lead with what was done (or what you disagree with and why). Reference specific changes briefly, not blow-by-blow.
- No jargon, no "AI-ese", no emoji.

Example (addressed): `"Moved the DynamicFilter narrowing before the TupleDomain intersection so the predicate can be pushed down on the first call. Thanks for catching this."` For push-backs or partial addresses, lead with the specific reason or what you applied vs what you didn't.

Show the draft to the user. Pause for approval.

### 2e. Post reply

Only after user approves the draft. Write the reply to a file and pass it via `-F body=@<path>` so newlines, quotes, and backslashes survive intact:
```
cat > /tmp/reply.txt <<'EOF'
<approved reply>
EOF
gh api repos/OWNER/REPO/pulls/NUM/comments \
  -X POST \
  -F body=@/tmp/reply.txt \
  -F in_reply_to=<original_comment_databaseId>
```

### 2f. Resolve thread — only if fully addressed

- **Fully addressed** (all feedback in the thread implemented): resolve via `resolveReviewThread` GraphQL mutation.
- **Partially addressed / pushed back / needs follow-up**: leave unresolved. The reply itself carries the status.
- **Stale** (code no longer exists): resolve with a reply noting that the referenced code was removed/restructured.

Thread IDs are opaque — use the `id` captured in Phase 1 step 2, or re-query. Don't derive them from comment IDs.

```graphql
mutation { resolveReviewThread(input: {threadId: "<thread_id>"}) { thread { isResolved } } }
```

## Phase 3 — Finalize

When the agenda is empty:

1. Show final state:
   - `git log --oneline "origin/$PR_BASE..HEAD"`
   - Summary of what was resolved, what remains unresolved (with reason), any CI items skipped
2. Ask: **"Force-push the updated branch?"** If yes, `git push --force-with-lease` (never `--force` — `--force-with-lease` refuses to clobber if someone else pushed in the meantime). If no, leave as-is.

## Constraints

- No `Co-Authored-By: Claude` in commit messages.
- No `git rebase -i` / `git add -i` (interactive flags are blocked by the harness). Use the `format-patch → reset → amend → apply` pattern instead.
- If a fix spans multiple commits in the stack, walk the user through the plan before starting.
- Before accepting a falsifiable reviewer claim, test it first. Reviewer bots are sometimes wrong; verifying guards against applying a wrong fix.

