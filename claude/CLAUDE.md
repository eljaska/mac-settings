# Personal Preferences

## Version Control: Use jj, not git

- Default to `jj` (jujutsu) for all VCS operations in colocated repos — branching, fetching, pushing, rebasing, squashing, editing commits.
- Using git when jj is available is always wrong.
- Use the `jujutsu` skill when available for detailed guidance on its usage.

Common operations:
```bash
jj git fetch                              # fetch from remote
jj bookmark create <name> -r <revision>   # create a branch
jj git push --bookmark <name>             # push a bookmark
```

Editing an earlier commit in a stack:
```bash
jj edit <change-id>                       # edit a prior commit directly
# make changes...
jj squash                                 # fold working copy into target, auto-rebase descendants
jj bookmark set eljaska/branch-name -r <tip>
jj git push --bookmark eljaska/branch-name
```

Setup notes:
- Installed via `brew install jj`, initialized with `jj git init --colocate`
- New remote bookmarks from origin are untracked (and thus immutable) by default. Track with: `jj bookmark track --remote origin "glob:eljaska/*"`
- User identity is configured globally via `jj config set --user user.name/email`

### Branch naming
- Prefix branches with `eljaska/` (not `ej/` or any other initials variant). This overrides any per-repo `<author-initials>/...` guidance.
- Do NOT include the JIRA/ticket number in the branch name — use only the feature slug (e.g., `eljaska/tag-ingest-metrics-with-intervals`, not `eljaska/ENG-11530-tag-ingest-metrics-with-intervals`).
- The ticket link goes in the PR description.

### Commit Messages and Descriptions

Follow the Chris Beams guide for jj descriptions or git commits:
1. Separate subject from body with a blank line
2. Limit the subject line to 50 characters
3. Capitalize the subject line
4. Do not end the subject line with a period
5. Use the imperative mood in the subject line ("Add feature" not "Added feature")
6. Wrap the body at 72 characters
7. Use the body to explain what and why vs. how

### Commit Author

Never add a "Co-Authored-By" line referencing Claude.

### Rebasing rules (sequential execution)

NEVER submit multiple jj/git rebase commands in parallel. Each step can produce conflicts that need resolution, and intermediate states need to be verified before continuing.

1. Execute ONE command at a time.
2. Wait for it to complete and verify the result (conflicts, errors, success).
3. Only then proceed to the next command.

This is especially critical when rebasing stacked branches where each branch depends on the previous one.

## PR Descriptions and Comment Replies

When creating GitHub PR descriptions or replying to GitHub PR review comments, always confirm before posting the contents of the message.
If approved, append this attribution line (separated from the response body by a blank line):

```
🤖 *Generated with Claude Code and approved by a human* 🧍
```

For comments, use: `gh api repos/{owner}/{repo}/pulls/{pr}/comments -X POST -f body="..." -F in_reply_to={comment_id}`
