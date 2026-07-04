---
name: pr
description: "Git and GitHub workflows: drafting commit messages (Chris Beams rules), structuring PRs as a sequence of focused commits, and creating starburst-enterprise pull requests. Use when drafting commit messages, creating or updating PRs, rebasing branches, or squashing fixup commits."
tags:
  - git
  - github
  - pull-request
  - commit-messages
  - workflow
---

# Git and GitHub

## Commit Messages

Draft concise commit messages that read well in `git log`, `jj log`, and code
review tools. Favor a short subject line, add a body only when extra context
helps, and explain the change in terms of user-visible intent and rationale.

### Inspect The Change

Start by understanding the exact scope of the change before writing anything.

- In a JJ repository, prefer `jj status`, `jj diff --git`, and `jj show @`.
- In a Git repository, prefer `git diff --cached` for staged changes and
  `git show --stat --patch` for an existing commit.
- If the diff mixes unrelated concerns, say so and recommend splitting the
  change before drafting a single commit message.
- Look for the user-facing effect, the problem being solved, and any risk,
  migration, or follow-up work that is not obvious from the diff alone.

### Draft The Message

Use the seven rules summarized in
[references/beams-rules.md](references/beams-rules.md).

- Write a subject line that stands on its own in one-line history views.
- Keep the subject at 50 characters or fewer when possible. If clarity needs a
  little more room, treat 72 as a practical ceiling.
- Capitalize the subject, omit the trailing period, and use imperative mood.
- Add a body only when the reason for the change is not obvious from the diff.
- Use the body to explain what changed, why it changed, important constraints,
  and any side effects. Avoid narrating line-by-line implementation details.
- Put ticket or issue references at the bottom when they matter.

### Review The Draft

Before returning a message, run these checks:

- Verify the subject completes the sentence: `If applied, this commit will ...`
- Verify the subject is specific enough to distinguish the change from nearby
  commits.
- Verify every body line wraps at about 72 characters.
- Verify the body adds rationale, tradeoffs, or context rather than repeating
  the subject.
- Verify the wording matches the actual diff. Do not claim unrelated effects.

### Respond To The User

Match the output to the request.

- If the user asks for a commit message, return the message text directly.
- If the body is unnecessary, return only the subject line.
- If there are several valid framings, offer up to three options and mark one
  as recommended with a short reason.
- If the user asks for feedback on an existing message, point out concrete
  issues against the checklist above and provide a rewrite.

---

## Structuring PR Commits

A well-structured PR tells a story commit by commit. The reviewer should be able
to read each commit in sequence, understand its purpose in isolation, and verify
that it does exactly one thing.

### The preparatory-commit pattern

Before writing the feature commit, identify the structural changes the feature
needs and split them into separate preparatory commits:

- **Rename** things that need to be renamed (rename only — no logic change).
- **Move** fields or methods to base classes (pure move — no logic change).
- **Extract** base classes or helpers (mechanical extraction — no logic change).
- **Enable** infrastructure (e.g., enable BIAC, add a config flag).

Then write the feature commit last. It will be small and focused because all
the ground was laid by the preparatory commits.

**Example (good):**
```
c727c93  Use proper class wrapping class
0a3f845  Rename TestBasicAuthentication to TestFilePasswordAuthentication
23bb458  Enable BIAC in BaseAuthenticationTest
b92754d  Move portalUrl field to BaseAuthenticationTest
401d148  Reuse newHttpClient() method
107aaac  Reuse fields for portal and cluster ports
20d4a9a  Extract BasePasswordAuthenticationTest
81db270  Add LDAP password authentication support to portal   ← small, clean
```

**Example (bad):**
```
81db270  Add LDAP password authentication support to portal
```
A single commit that renames the test class, moves fields to a base class,
enables BIAC, *and* adds the feature. The reviewer cannot tell what is
structural vs. what is logic.

### Rules for individual commits

1. **Single responsibility** — one commit does one logical thing. No "and" in
   the subject. If you need "and", split the commit.
2. **Dependency order** — each commit must compile and make sense on its own.
   Earlier commits must not reference code that only exists in later ones.
3. **Mechanical vs. logic** — isolate pure mechanical operations (rename, move,
   extract) from any logic changes, even when they target the same files.
   This lets a reviewer say "this is just a rename — nothing changed logically."
4. **Feature commit is small by design** — if the feature commit is large,
   it usually means some preparatory work was not extracted into its own commit.

### Why this matters

When commits are structured this way, reviewer comments on a given commit are
about *one focused thing*. The fix is then equally focused, the fixup commit is
small, and there is no risk of conflict when squashing. The fixup-heavy/conflict
approach is usually a symptom of commits that mixed too many concerns.

To work through reviewer comments on a PR, use the `/address-review-feedback`
skill — it handles the full workflow of triaging threads, applying fixes into
the right commits, and posting replies.

---

## Pull Requests (starburst-enterprise)

`gh` is at `/opt/homebrew/bin/gh`.

Always use the PR template from `.github/PULL_REQUEST_TEMPLATE.md` (read it first).

Rules:
1. **Jira link is required** — always include it under "Related JIRA issue, PRs, and other resources"
2. **Less is more** — description should be concise (1–3 sentences max). State what changed and why, not how.
3. Fill the template sections; don't add extra headers.

Example (good):
```
## Description

Adds LDAP password authentication support to the Starburst Portal.

## Related JIRA issue, PRs, and other resources

- Fixes: https://starburstdata.atlassian.net/browse/ENG-XXXXX
```

## Constraints

- No `Co-Authored-By: Claude` trailer in commit messages.
