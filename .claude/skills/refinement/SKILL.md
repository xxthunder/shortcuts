---
name: refinement
description: "Start a backlog refinement session to discuss the project mission, review backlog items, prioritize work, and align on next steps. Trigger with: 'another refinement session', 'let's refine', 'refinement time', 'backlog refinement', or similar requests to discuss project direction and priorities."
user_invocable: true
---

# Refinement Session

Interactive backlog refinement session for the Shortcuts project. Reviews project mission, current state, backlog items, and documentation to align on priorities and next steps.

## When This Skill Triggers

Use this skill when the user wants to discuss project direction, priorities, or backlog:

- "Another refinement session"
- "Let's refine"
- "Refinement time"
- "Backlog refinement"
- "Let's discuss the backlog"
- "What should we work on next?"
- Any request to review project status and priorities

## Workflow

### Step 1: Load Project Context

Read the following files to understand current project state:

1. **`README.md`** - Project mission and user-facing documentation
2. **`docs/backlog.md`** - Current backlog items (TODO, IN PROGRESS, DONE)
3. **`docs/roadmap.md`** - High-level vision and planned features
4. **`docs/development-principles.md`** - Core development principles

Also check:

5. **`git log --oneline -20`** - Recent activity to understand momentum
6. **`git branch -a`** - Active branches to understand work in progress

### Step 2: Present Session Summary

Present a concise overview to the user:

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

After presenting the summary, ask the user what they'd like to focus on:

```
What would you like to discuss?

1. **Prioritize** - Review and reorder backlog items
2. **Deep dive** - Explore a specific backlog item in detail
3. **New ideas** - Add new items to the backlog
4. **Architecture** - Discuss technical direction or decisions
5. **Cleanup** - Review completed items, close stale items, update docs
```

Use AskUserQuestion to let the user choose their focus area.

### Step 4: Topic-Specific Facilitation

Based on the user's choice:

#### Prioritize
- Walk through each TODO item
- Ask about relative priority and dependencies
- Suggest ordering based on dependencies and value
- Update `docs/backlog.md` priorities if agreed

#### Deep Dive
- Read the full backlog item details
- Read related source files and tests
- Identify open questions, risks, and dependencies
- Discuss implementation approach
- Use EnterPlanMode if the discussion leads to implementation planning

#### New Ideas
- Help the user articulate the idea
- Draft a backlog item following the existing format (ID, status, priority, component, description, acceptance criteria)
- Add to `docs/backlog.md` after user approval

#### Architecture
- Read relevant source files (AGENTS.md, pslib/, etc.)
- Discuss technical decisions and trade-offs
- Document decisions if needed

#### Cleanup
- Review DONE items - any follow-up needed?
- Check for stale TODO items
- Update documentation if outdated
- Propose items to archive or remove

### Step 5: Capture Outcomes

At the end of the session, summarize what was discussed and any actions taken:

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

If any changes were made to `docs/backlog.md` or other files, **do NOT commit automatically**.
Present the session outcomes summary and let the user review the changes via `git diff` first.
Only commit when the user explicitly asks. Suggested commit message:
```
docs: update backlog from refinement session
```

## Guidelines

- **Keep it conversational** - This is a collaborative discussion, not a status report
- **Ask questions** - Help the user think through priorities and trade-offs
- **Be opinionated** - Offer suggestions based on project context (dependencies, technical debt, user value)
- **Stay focused** - One topic at a time, don't try to cover everything
- **Respect the user's direction** - They know their priorities best
- **Use existing format** - New backlog items should follow the established format in `docs/backlog.md`
- **Link to code** - When discussing items, reference specific files and line numbers
- **Never auto-commit** - Always let the user review changes via `git diff` before committing. Only commit when explicitly asked
