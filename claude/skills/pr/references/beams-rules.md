# Chris Beams Commit Message Rules

Source: [How to Write a Git Commit Message](https://cbea.ms/git-commit/)

Use this reference when you need the detailed rule set or a reminder of the
reasoning behind the format.

## The Seven Rules

1. Separate the subject from the body with a blank line.
2. Keep the subject line to about 50 characters.
3. Capitalize the first word of the subject.
4. Do not end the subject with a period.
5. Use imperative mood in the subject.
6. Wrap body lines at about 72 characters.
7. Use the body to explain what changed and why, not to restate how.

## Subject Line Guidance

Aim for a short line that still tells a reviewer what changed.

Good patterns:

- `Add null-aware integer division`
- `Fix mask handling in grouped aggregation`
- `Remove unused vector allocation`

Weak patterns:

- `fixed stuff`
- `changes to aggregation`
- `more work on evaluator`

Prefer a subject that passes this test:

`If applied, this commit will <subject>.`

Examples:

- `If applied, this commit will fix mask handling in grouped aggregation.`
- `If applied, this commit will remove unused vector allocation.`

This test usually catches past tense, vague nouns, and descriptive fragments.

## When To Add A Body

Skip the body when the change is tiny and the diff already tells the full
story.

Add a body when a reviewer would otherwise have to infer context, such as:

- the bug or user problem that motivated the change
- an important design choice or tradeoff
- behavior changes, performance implications, or compatibility notes
- follow-up work, limitations, or issue references

## Body Checklist

Write short paragraphs that explain intent and consequences.

- Explain the problem first.
- Explain the reason for the chosen fix.
- Mention non-obvious side effects or constraints.
- Reference issues at the bottom when useful.
- Avoid copying filenames or narrating the diff line by line.

## Output Template

Use this shape:

```text
Imperative subject line

Explain what changed and why.

Add another paragraph only when it carries distinct context.

Refs: #123
```
