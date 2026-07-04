---
name: suggest-skills
description: Suggest relevant skills based on user input. Use when user mentions "suggest skills" or "recommend skills" in their query.
tags:
  - skills
  - recommendation
  - automation
  - workflow
---
# Suggest Relevant Skills

### Step 1: [Read prior conversation and identify user needs]
- Look at the 30 most recent Claude Code sessions from ~/.claude/projects and identify any workflows that are repeated more than 3 times that can be converted into skills. 
- Only suggest repeated patterns if they are not already covered by an existing skill or command. Focus on identifying gaps where a new skill could provide value by automating repeated common tasks or workflow that users are performing manually.
- Only look for patterns that are repeated more than 3 times across the conversations to reduce noise.

### Step 2: [Present suggested skills to the user]
- Show the user a list of the top 5 suggested skills based on the patterns identified in Step 1. For each suggested skill, provide a brief description of what the skill would do and how it would help automate a common task or workflow that the user is performing manually.
- Ask the user if they would like to create any of the suggested skills. If the user says yes, then proceed to the skill creation process. 
- If the user says no, then stop and exit.

### Step 3: [Create the skills]
- If the user said yes in Step 2, then create the skill(s) in the user scope based on the suggestions. 
- For each skill, define the name, description, compatibility requirements, and tags. Then define the logic for the skill to automate the identified task or workflow. Structure the skill as a single Markdown file named SKILL.md (exact casing) with the following format:
```
---
name: <skill_name>
description: <skill_description>
compatibility: <compatibility_requirements>
tags:
  - <tag1>
  - <tag2>
  - <tag3>
---
# <Skill name>
  <implementation_logic>
```
- After creating the skill(s), provide a summary of the new skills that were created and how they can be used to automate the tasks or workflows that were previously being done manually.
