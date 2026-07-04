---
name: jujutsu
description: >
  Expert guidance on Jujutsu (jj), the Git-compatible version control system.
  Use this skill whenever a user mentions jj, jujutsu, "jj command", "jj workflow",
  or asks how to do something in jj vs git. Also trigger when a user asks about
  replacing git commands, managing stacks of commits/changes, working with jj
  bookmarks, jj rebase, jj squash, jj split, jj undo, or any jj-specific concept.
  This skill should also trigger when users are migrating from git to jj, setting
  up jj for the first time, or troubleshooting jj behavior.
---

# Jujutsu (jj) Skill

Jujutsu (`jj`) is a Git-compatible version control system with a cleaner mental
model. It uses a "changes" abstraction (mutable, stable IDs) over immutable commits,
making history editing safe and easy. The working copy is always a commit — no
staging area, no stash needed.

## Agent Workflow Rule

- When a set of tasks is complete, create a fresh empty working-copy revision on
  top of the completed revision so later unrelated edits do not accumulate in the
  finished change.
- Prefer `jj commit -m "..."` when you are finalizing the current revision and
  want to create that empty successor revision in one step.
- If the completed revision is already described and should remain unchanged, run
  `jj new` immediately after finishing the task set. Leave the new revision
  intentionally empty and with no description.

## Core Mental Model Differences from Git

| Concept | Git | jj |
|---|---|---|
| Working copy | Dirty state, not a commit | Always a commit (`@`) |
| Staging | `git add` / index | None — all edits auto-tracked |
| Branches | Named, must be checked out | Bookmarks (optional); anonymous branches native |
| Amending | Only HEAD | Any commit, auto-rebases descendants |
| Conflicts | Block operations | Stored in tree, resolve when ready |
| Undo | Complex (`reflog`) | `jj undo` reverses any operation |

**Change IDs** are stable even as the underlying commit hash changes (e.g. after
amend/rebase). `@` always refers to the working-copy commit.

---

## Setup

```bash
# Install (macOS)
brew install jj

# Clone a repo (colocated = git commands still work too)
jj git clone --colocate <url>

# Or add jj to an existing git repo
cd my-repo
jj git init --colocate

# Configure identity
jj config set --user user.name "Your Name"
jj config set --user user.email "you@example.com"
```

---

## Essential Daily Commands

### Viewing State

```bash
jj log              # Visual commit graph (like git log --graph)
jj log -r 'all()'  # Show all commits
jj status           # Show changed files in @ (working copy)
jj diff             # Diff of working-copy commit
jj diff -r <id>    # Diff of specific change
jj show <id>       # Full details of a change
```

### Creating & Describing Changes

```bash
# Start a new change (like git checkout -b + empty commit)
jj new

# Describe (set commit message) for current change
jj describe -m "feat: add login button"

# Combined: finish current change and start next
jj commit -m "feat: add login button"   # = describe + new

# Edit an old commit directly (jj auto-rebases descendants!)
jj edit <change-id>
```

### Undoing & Safety

```bash
jj undo             # Undo the last jj operation (very safe)
jj op log           # Show operation history
jj op restore <id>  # Restore repo to earlier operation state
```

### Rewriting History

```bash
# Squash working copy into parent
jj squash

# Squash into specific target
jj squash --into <id>

# Interactively pick hunks to squash
jj squash --interactive

# Split a change into two
jj split
jj split --interactive

# Rebase onto a new parent
jj rebase -d <destination>

# Rebase a whole branch
jj rebase -s <source> -d <destination>
```

### Bookmarks (≈ Git Branches)

```bash
jj bookmark list              # List all bookmarks
jj bookmark create my-feature  # Create bookmark at @
jj bookmark set my-feature     # Move bookmark to @
jj bookmark delete my-feature

# Push to remote
jj git push --bookmark my-feature

# Fetch from remote
jj git fetch
```

---

## Git Equivalents Cheatsheet

| Git | jj |
|---|---|
| `git status` | `jj status` |
| `git log --graph` | `jj log` |
| `git diff` | `jj diff` |
| `git add -A && git commit -m "msg"` | `jj commit -m "msg"` |
| `git commit --amend` | `jj describe` (or just edit files — auto-amends) |
| `git stash` | Not needed — working copy is already a commit |
| `git checkout -b feature` | `jj new; jj bookmark create feature` |
| `git switch branch` | `jj new <bookmark-name>` or `jj edit <id>` |
| `git rebase -i HEAD~3` | `jj rebase`, `jj squash`, `jj split` |
| `git cherry-pick <sha>` | `jj rebase -r <id> -d @` |
| `git push` | `jj git push` |
| `git fetch` | `jj git fetch` |
| `git blame` | `jj file annotate <path>` |
| `git reflog` | `jj op log` |
| `git reset --hard` | `jj abandon` (abandon change) |

---

## Common Workflows

### Fixing an Old Commit

```bash
jj log                    # find the change ID, e.g. "abc123"
jj edit abc123            # working copy becomes that change
# edit files...
jj describe -m "fixed msg"
jj new main               # return to tip of main
# jj auto-rebased all descendants — no manual rebase needed
```

### Stacked PRs / Changes

```bash
jj new main -m "feat: part 1"
# write code...
jj new -m "feat: part 2"
# write more code...

# View stack
jj log

# Rebase entire stack when main updates
jj git fetch
jj rebase -d main         # rebases current change and all ancestors
```

### Conflict Resolution (Non-Blocking)

```bash
jj rebase -d main         # succeeds even with conflicts
jj status                 # shows conflicted files
# edit files to resolve...
jj diff                   # verify resolution
# no "git rebase --continue" needed — it's auto-detected
```

### Splitting a Change

```bash
jj split                  # interactive hunk picker: split @ into two changes
jj split --interactive    # same
jj split -r <id>          # split a specific past change
```

---

## Revset Language

`jj` uses a powerful revset syntax for referring to commits:

```
@               current working-copy commit
@-              parent of @
main            tip of bookmark "main"
..@             all commits from root to @
main..@         commits reachable from @ but not main
all()           every commit
ancestors(@)    all ancestors of @
```

Examples:
```bash
jj log -r 'main..@'          # changes ahead of main
jj log -r 'description("wip")'  # changes with "wip" in message
```

---

## Tips & Best Practices

- **Use colocated mode** when you still need `git` commands (e.g. IDE git integrations).
- **Don't fear `jj rebase`** — `jj undo` is a reliable escape hatch.
- **Finish task sets with a new empty revision** — run `jj new` after a completed
  change when needed, or use `jj commit -m "..."` to finalize the change and
  create the empty follow-up revision in one step.
- **Label WIP changes** with `jj describe -m "wip: ..."` so they're findable in `jj log`.
- **`jj squash --interactive`** is the equivalent of `git add -p` + commit.
- Bookmarks are optional for local work; you only need them to push to GitHub/GitLab.

---

## Further Reading

- Official docs: https://docs.jj-vcs.dev/latest/
- Git comparison table: https://docs.jj-vcs.dev/latest/git-comparison/
- Steve Klabnik's tutorial: https://steveklabnik.github.io/jujutsu-tutorial/
- CLI reference: https://docs.jj-vcs.dev/latest/cli-reference/
