# Backlog Format Reference

This defines the backlog structure, entry format, and conventions used by the refinement skill. Use this reference when creating a new backlog or adding entries to an existing one.

## File Structure

The backlog is a single markdown file with these sections in order:

```markdown
# Backlog

## Status Legend

- **IN PROGRESS** - Currently being worked on
- **TODO** - Ready to be picked up
- **DONE** - Completed

## Table of Contents

### In Progress
- [ID — Title](#anchor)

### TODO
- [ID — Title](#anchor)

### Done
- [ID — Title](#anchor)

---

## IN PROGRESS

### [ID] Title
[entry fields]

---

## TODO

### [ID] Title
[entry fields]

---

## DONE

### [ID] Title
[entry fields]

---

## Notes

- **ID prefix**: `PREFIX` (e.g., `HSH` for HomeSweetHome)
- Keep items actionable with clear acceptance criteria
- Do NOT list commit hashes in backlog entries — the backlog is part of the commit itself, so hashes are circular and go stale after squash/rebase
```

## Item ID Convention

Format: `[PREFIX-###]` — project prefix + zero-padded sequential number.

- The prefix is a short, memorable abbreviation of the repository/project name (e.g., `HSH` for HomeSweetHome).
- Numbers are **global and sequential** across all items — no per-type numbering, no gaps intentional.
- The prefix is stored in the **Notes** section of the backlog so it is always discoverable.

Examples: `HSH-001`, `HSH-002`, `HSH-015`

When adding a new item, scan all existing IDs in the backlog to find the highest number, then increment by one.

## Entry Fields

### Required fields (all entries)

| Field                  | Description                                              |
|------------------------|----------------------------------------------------------|
| **Status**             | `Open` (TODO), `Ongoing` (IN PROGRESS), or completed format (see below) |
| **Priority**           | `High`, `Medium`, `Low`, or `—` (none)                  |
| **Component**          | File path(s) affected (e.g., `roles/ssl-certify/`)       |
| **Summary**            | User story: "As a [user], I want [feature] so that [benefit]" |
| **Description**        | Detailed problem statement, current state, rationale     |
| **Acceptance Criteria**| Checkbox list: `- [ ] Criterion` (unchecked) / `- [x] Criterion` (checked) |

### Optional fields

| Field                    | When to include                                     |
|--------------------------|-----------------------------------------------------|
| **Depends on**           | When blocked by another item (e.g., `HSH-006`)     |
| **Related**              | When related to other items (not blocking)           |
| **Scope Decisions**      | When key architectural choices have been made        |
| **Technical Notes**      | Implementation-specific details (socket paths, config snippets) |
| **Dependencies**         | External system prerequisites                        |
| **Related Documentation**| Links to guides or external references               |

### Open / TODO entry

```markdown
### [HSH-015] Brief descriptive title

**Status**: Open
**Priority**: Medium
**Component**: `path/to/affected/file.ext`

**Summary**:
As a [user role], I want [feature] so that [benefit].

**Description**:
[Problem statement. Current behavior. Why this matters.]

**Acceptance Criteria**:
- [ ] First verifiable criterion
- [ ] Second verifiable criterion
- [ ] All existing tests continue to pass
```

### In Progress entry

Same as TODO but with `**Status**: Ongoing` and some criteria may be checked off.

### Completed entry

```markdown
### [HSH-001] ✅ COMPLETED - Brief descriptive title

**Status**: **Completed** (YYYY-MM-DD) | **Branch**: `branch-name`
**Priority**: Medium
**Component**: `path/to/affected/file.ext`

[... all other fields with all acceptance criteria checked ...]
```

### TOC entry format

```markdown
### In Progress
- [HSH-014 — Backlog refinement](#hsh-014-backlog-refinement)

### TODO
- [HSH-015 — Brief title](#hsh-015-brief-descriptive-title)

### Done
- [HSH-001 — Brief title](#hsh-001--completed---brief-descriptive-title)
```

Note: completed items include `--completed---` in the anchor because of the `✅ COMPLETED -` prefix in the heading.

## Ongoing Refinement Item

Every backlog should include an ongoing refinement item that is never completed. All refinement commits reference this ID:

```markdown
### [PREFIX-0XX] Backlog refinement

**Status**: Ongoing
**Priority**: —

**Description**:
Ongoing backlog refinement — create, review, clarify, and update user stories. Add research findings, scope decisions, acceptance criteria, and implementation details as needed. This item is never completed; all refinement commits reference this ID.
```

## Status Transitions

```
Open (TODO) → Ongoing (IN PROGRESS) → Completed (DONE)
```

When moving items:
1. Update the `**Status**` field
2. Move the entry to the correct section (TODO / IN PROGRESS / DONE)
3. Update the Table of Contents links
4. For completed items: add date, branch name, and `✅ COMPLETED -` prefix to heading
