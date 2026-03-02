# Backlog Format Reference

This defines the backlog structure, entry format, and conventions used by the refinement skill. Use this reference when creating a new backlog or adding entries to an existing one.

## File Structure

The backlog uses a folder-based layout with one file per item:

```
docs/backlog/
├── index.md              # Status legend, TOC with links, Notes
├── in_progress/
│   ├── prefix-001.md     # Each item is a standalone file
│   └── prefix-007.md
├── todo/
│   ├── prefix-002.md
│   └── prefix-003.md
└── done/
    ├── prefix-004.md
    └── prefix-005.md
```

### `index.md`

Contains only metadata and navigation — no item content:

```markdown
# Backlog

## Status Legend

- **IN PROGRESS** - Currently being worked on
- **TODO** - Ready to be picked up
- **DONE** - Completed

## Table of Contents

### In Progress
- [ID — Title](in_progress/id.md)

### TODO
- [ID — Title](todo/id.md)

### Done
- [ID — Title](done/id.md)

---

## Notes

- **ID prefix**: `PREFIX` (e.g., `HSH` for HomeSweetHome)
- Keep items actionable with clear acceptance criteria
- Do NOT list commit hashes in backlog entries — the backlog is part of the commit itself, so hashes are circular and go stale after squash/rebase
```

### Item files

Each item lives in the folder matching its status. The heading is `#` (top-level, since it's the only item in the file):

```markdown
# [PREFIX-015] Brief descriptive title

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

## Item ID Convention

Format: `[PREFIX-###]` — project prefix + zero-padded sequential number.

- The prefix is a short, memorable abbreviation of the repository/project name (e.g., `HSH` for HomeSweetHome).
- Numbers are **global and sequential** across all items — no per-type numbering, no gaps intentional.
- The prefix is stored in the **Notes** section of `index.md` so it is always discoverable.

Examples: `HSH-001`, `HSH-002`, `HSH-015`

When adding a new item, scan all existing IDs across all folders to find the highest number, then increment by one.

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

File: `todo/prefix-015.md`

```markdown
# [HSH-015] Brief descriptive title

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

Same as TODO but with `**Status**: Ongoing` and some criteria may be checked off. File lives in `in_progress/`.

### Completed entry

File: `done/prefix-001.md`

```markdown
# [HSH-001] ✅ COMPLETED - Brief descriptive title

**Status**: **Completed** (YYYY-MM-DD) | **Branch**: `branch-name`
**Priority**: Medium
**Component**: `path/to/affected/file.ext`

[... all other fields with all acceptance criteria checked ...]
```

### TOC entry format (in `index.md`)

```markdown
### In Progress
- [HSH-014 — Backlog refinement](in_progress/hsh-014.md)

### TODO
- [HSH-015 — Brief title](todo/hsh-015.md)

### Done
- [HSH-001 — Brief title](done/hsh-001.md)
```

## Ongoing Refinement Item

Every backlog should include an ongoing refinement item that is never completed. All refinement commits reference this ID:

File: `in_progress/prefix-0xx.md`

```markdown
# [PREFIX-0XX] Backlog refinement

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
1. Move the item file between folders: `git mv todo/prefix-015.md in_progress/prefix-015.md`
2. Update the `**Status**` field inside the file
3. Update the Table of Contents links in `index.md` (move the link to the correct section, update the relative path)
4. For completed items: add date, branch name, and `✅ COMPLETED -` prefix to heading
