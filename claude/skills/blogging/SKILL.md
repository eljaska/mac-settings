---
name: blogging
description: Guide the user through creating a technical blog post from initial concept to final markdown. Gather context, create an outline, iterate based on feedback, and generate the final post with appropriate tone. Use this skill when the user asks for "help writing a blog post", "write a blog" or similar requests.
model: opus
tags:
  - workflow
  - writing
  - documentation
  - content
---

# Blogging Workflow

## Overview

Help the user create a technical blog post by following a structured workflow: gather context, create an outline, iterate on structure and content, then generate the final markdown document. The goal is to produce educational, engineering-focused content that tells a story rather than selling a product.

## Gather Context

Start by understanding what the user wants to write about and collecting relevant information.

- Ask the user to describe the blog topic and key points they want to cover
- If external documentation or references are mentioned, use WebFetch to extract relevant details
- Identify the target audience (engineers, product managers, general technical audience)
- Note any specific requirements:
  - Tone (educational, conversational, formal)
  - Length constraints
  - Key messages or takeaways
  - Technical details to include or exclude

## Create the Outline

Draft a structured outline based on the gathered context.

- Start with a clear introduction that establishes the problem or story
- Break the content into logical sections with descriptive headers
- For technical posts, typically include:
  - Problem statement or context
  - Technical setup or architecture
  - Implementation details or workflow
  - Results or insights
  - Future direction or wrap-up
- Keep the outline at a high level (section headers plus bullet points)
- Present the outline to the user for review

## Iterate on the Outline

Work with the user to refine the structure before writing the full post.

- Ask for specific feedback on each section
- Be ready to:
  - Add, remove, or reorder sections
  - Adjust the level of technical detail
  - Incorporate specific points or examples
  - Change the narrative flow
- Continue iterating until the user approves the structure
- This step saves time by ensuring alignment before writing the full content

## Generate the Blog Post

Write the full blog post as a markdown document.

- Use the approved outline as the structure
- Write in the requested tone:
  - **Educational**: focus on teaching, use clear explanations, avoid sales language
  - **Conversational**: write as if talking through your experience, use "I" and "we", include personal asides
  - **Formal**: maintain professional distance, focus on facts and results
- Keep writing crisp and concise:
  - Avoid redundant or repetitive sentences
  - Avoid filler phrases like "I'll be honest", "to be honest"
  - Lead with the key point, then provide supporting details
  - Use code examples where relevant
  - Break up long paragraphs
- Create the markdown file in the current working directory
- Use a descriptive filename (e.g., `topic-name-key-concept.md`)

## Offer Alternate Versions

If the user wants a different tone or style, generate alternate versions.

- Create a new file with a version suffix (e.g., `-v2.md`)
- Preserve the structure and content, but adjust the writing style:
  - More/less conversational
  - More/less technical detail
  - Different narrative framing
- Explain the key differences between versions

## Best Practices

- **Write from an engineer's perspective**: focus on the problem, the solution, and what was learned
- **Tell a story**: help the reader follow the journey from problem to solution
- **Be specific**: use concrete examples, real prompts, actual code
- **Avoid sales pitches**: let the reader draw their own conclusions about the tools
- **Include links**: reference documentation, related posts, or resources
- **Show, don't just tell**: use code snippets, sample queries, or screenshots where helpful

## When to Use This Skill

Invoke this skill when the user wants to:
- Write a technical blog post
- Create content about a software project or feature
- Document a workflow or process in blog format
- Share lessons learned or case studies
- Need help structuring long-form technical content
