<!-- Source: https://github.com/xxthunder/my-agentic-skills/tree/develop/refinement -->
---
name: refinement
description: "Start a backlog refinement session to discuss the project mission, review backlog items, prioritize work, and align on next steps. Also bootstraps the backlog structure in greenfield projects. Trigger with: 'another refinement session', 'let's refine', 'refinement time', 'backlog refinement', or similar requests to discuss project direction and priorities."
user_invocable: true
---

# Refinement Session

Interactive backlog refinement session. Reviews project mission, current state, backlog items, and documentation to align on priorities and next steps. Bootstraps the backlog in greenfield projects.

## When This Skill Triggers

- "Another refinement session" / "Let's refine" / "Refinement time"
- "Backlog refinement" / "Let's discuss the backlog"
- "What should we work on next?"
- Any request to review project status and priorities

## Workflow

### Step 1: Load Project Context

Discover and read project documentation to understand current state. Look for:

1. **`README.md`** - Project mission and user-facing documentation
2. **Backlog file** - `docs/backlog.md`, `BACKLOG.md`, or equivalent
3. **Roadmap** - `docs/roadmap.md` or equivalent
4. **Development principles** - `docs/development-principles.md`, `CONTRIBUTING.md`, or equivalent

Also check:

5. **`git log --oneline -20`** - Recent activity
6. **`git branch -a`** - Active branches

**If no backlog file exists** → go to Step 1b (Bootstrap).
**If a backlog file exists** → skip to Step 2.

### Step 1b: Bootstrap Backlog (Greenfield)

When no backlog file is found, create one:

1. Read **[references/backlog-format.md](references/backlog-format.md)** for the complete format specification
2. Ask the user where the backlog should live (default: `docs/backlog.md`)
3. Ask the user for a **project ID prefix** — a short uppercase abbreviation of the repo/project name (e.g., `HSH` for HomeSweetHome). Store it in the Notes section of the backlog.
4. Create the backlog file with the skeleton structure (Status Legend, TOC, empty sections, Notes)
5. Create the ongoing refinement item (`[PREFIX-001]`) as the first entry in IN PROGRESS
6. Ask the user if they have initial ideas to seed the backlog — draft entries using the format from the reference

**Do NOT commit automatically.** Let the user review via `git diff` first.

### Step 2: Present Session Summary

```
## Refinement Session

### Project Mission
[1-2 sentence summary from README.md]

### Current State
- **Active branch**: [current branch and what it's about]
- **Recent activity**: [summary of last few commits]

### Backlog Overview
**In Progress**: [count and brief list]
**TODO**: [count and brief list with IDs]
**Recently Completed**: [count and last 1-2 completed items]

### Open Items for Discussion
[List each TODO item with ID, title, priority, and a 1-line summary]
```

### Step 3: Facilitate Discussion

Use AskUserQuestion to let the user choose their focus area:

1. **Prioritize** - Review and reorder backlog items
2. **Deep dive** - Explore a specific backlog item in detail
3. **New ideas** - Add new items to the backlog
4. **Architecture** - Discuss technical direction or decisions
5. **Cleanup** - Review completed items, close stale items, update docs

### Step 4: Topic-Specific Facilitation

#### Prioritize
- Walk through each TODO item
- Ask about relative priority and dependencies
- Suggest ordering based on dependencies and value
- Update backlog priorities if agreed

#### Deep Dive
- Read the full backlog item details
- Read related source files and tests
- Identify open questions, risks, and dependencies
- Discuss implementation approach
- Use EnterPlanMode if the discussion leads to implementation planning

#### New Ideas
- Help the user articulate the idea
- Read **[references/backlog-format.md](references/backlog-format.md)** for the entry template and ID convention
- Read the project prefix from the **Notes** section of the backlog
- Determine the next available ID number (scan all existing IDs, take the highest number, increment by one)
- Draft a backlog entry with all required fields using `[PREFIX-###]` format
- Add to backlog after user approval

#### Architecture
- Read relevant source files and architecture docs
- Discuss technical decisions and trade-offs
- Document decisions in the backlog item's Scope Decisions field

#### Cleanup
- Review DONE items - any follow-up needed?
- Check for stale TODO items
- Update documentation if outdated
- Propose items to archive or remove

### Step 5: Capture Outcomes

```
## Session Outcomes

### Decisions Made
- [list decisions]

### Backlog Changes
- [items added, updated, reprioritized, or removed]

### Next Steps
- [what to work on next]
- [any follow-up items]
```

**Do NOT commit automatically.** Let the user review changes via `git diff` first. Only commit when explicitly asked.

## Guidelines

- **Keep it conversational** - Collaborative discussion, not a status report
- **Ask questions** - Help the user think through priorities and trade-offs
- **Be opinionated** - Offer suggestions based on project context
- **Stay focused** - One topic at a time
- **Respect the user's direction** - They know their priorities best
- **Use the format reference** - New/modified entries must follow [references/backlog-format.md](references/backlog-format.md)
- **Link to code** - Reference specific files and line numbers when discussing items
- **Never auto-commit** - Always let the user review first
