# [CHORE-001] ✅ COMPLETED - Move reusable skills to global ~/.claude/skills

**Status**: **Completed** (2026-02-22) | **Branch**: `refinement`
**Priority**: Low
**Component**: `.claude/skills/`

**Description**:
Moved refinement, retrospective, and skill-creator skills to a dedicated git repo (`xxthunder/my-agentic-skills`) and configured them globally via `~/.claude/skills/`. Generalized project-specific references in refinement and retrospective skills. Removed project-level copies.

**Acceptance Criteria**:
- [x] Global skills repo created and pushed to GitHub
- [x] Generalized refinement and retrospective skills (removed project-specific references)
- [x] skill-creator copied as-is (already generic)
- [x] Project-level copies removed
