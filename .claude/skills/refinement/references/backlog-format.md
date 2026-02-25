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

- Use format `[TYPE-###]` for item IDs (e.g., `BUG-001`, `FEAT-001`, `DEBT-001`)
- Keep items actionable with clear acceptance criteria
- Do NOT list commit hashes in backlog entries — the backlog is part of the commit itself, so hashes are circular and go stale after squash/rebase
```

## Item ID Convention

Format: `[TYPE-###]` — type prefix + zero-padded sequential number.

| Type    | Use for                          | Example    |
|---------|----------------------------------|------------|
| FEAT    | New feature                      | FEAT-001   |
| BUG     | Bug fix                          | BUG-002    |
| REFACT  | Refactoring                      | REFACT-003 |
| CHORE   | Maintenance / housekeeping       | CHORE-001  |
| CI      | CI/CD pipeline changes           | CI-001     |
| DEBT    | Technical debt                   | DEBT-001   |

Numbers are global across all types (i.e., after FEAT-001 and BUG-002, the next item is ###-003 regardless of type).

## Entry Fields

### Required fields (all entries)

| Field                  | Description                                              |
|------------------------|----------------------------------------------------------|
| **Status**             | `Open` (TODO), `Ongoing` (IN PROGRESS), or completed format (see below) |
| **Priority**           | `High`, `Medium`, `Low`, or `—` (none)                  |
| **Component**          | File path(s) affected (e.g., `tools/pslib/wsl/wsl-manager.ps1`) |
| **Summary**            | User story: "As a [user], I want [feature] so that [benefit]" |
| **Description**        | Detailed problem statement, current state, rationale     |
| **Acceptance Criteria**| Checkbox list: `- [ ] Criterion` (unchecked) / `- [x] Criterion` (checked) |

### Optional fields

| Field                    | When to include                                     |
|--------------------------|-----------------------------------------------------|
| **Depends on**           | When blocked by another item (e.g., `REFACT-006`)   |
| **Related**              | When related to other items (not blocking)           |
| **Scope Decisions**      | When key architectural choices have been made        |
| **Technical Notes**      | Implementation-specific details (socket paths, config snippets) |
| **Dependencies**         | External system prerequisites                        |
| **Related Documentation**| Links to guides or external references               |

### Open / TODO entry

```markdown
### [FEAT-001] Brief descriptive title

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
### [FEAT-001] ✅ COMPLETED - Brief descriptive title

**Status**: **Completed** (YYYY-MM-DD) | **Branch**: `branch-name`
**Priority**: Medium
**Component**: `path/to/affected/file.ext`

[... all other fields with all acceptance criteria checked ...]
```

### TOC entry format

```markdown
### In Progress
- [CHORE-002 — Backlog refinement](#chore-002-backlog-refinement)

### TODO
- [FEAT-001 — Brief title](#feat-001-brief-descriptive-title)

### Done
- [FEAT-001 — Brief title](#feat-001--completed---brief-descriptive-title)
```

Note: completed items include `--completed---` in the anchor because of the `✅ COMPLETED -` prefix in the heading.

## Ongoing Refinement Item

Every backlog should include an ongoing refinement item that is never completed. All refinement commits reference this ID:

```markdown
### [CHORE-0XX] Backlog refinement

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
