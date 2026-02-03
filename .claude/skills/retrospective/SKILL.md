---
name: retrospective
description: "Incident-driven learning and guideline improvement. Use when the user expresses dissatisfaction with Claude's work, approach, or decisions. Triggers include: 'I am not happy', 'this is not what I wanted', 'you shouldn't have done that', 'why did you...', 'that's wrong', or any indication of unmet expectations. Captures what went wrong and updates development-principles.md or AGENTS.md to prevent recurrence."
---

# Retrospective: Incident-Driven Learning

This skill helps capture lessons when work doesn't meet expectations and encodes them into project guidelines to prevent future issues.

## When This Skill Triggers

Use this skill whenever the user indicates dissatisfaction or unmet expectations:

- "I am not happy with..."
- "This is not what I wanted"
- "You shouldn't have done that"
- "Why did you [do X]?"
- "That's wrong" or "This is incorrect"
- Any indication that Claude's approach, decisions, or output didn't align with user expectations

## Workflow

### Step 1: Acknowledge and Understand

When triggered, immediately:

1. Acknowledge the issue without being defensive
2. Ask clarifying questions to understand:
   - **What specifically went wrong?** (behavior, output, approach, decision)
   - **What was expected instead?** (desired behavior, correct output, better approach)
   - **Impact**: How significant was this issue? (Minor inconvenience vs. major blocker)

Example:
```
I understand this didn't meet your expectations. To help me learn:
- What specifically about [X] was problematic?
- What would have been the correct approach?
- Is this a one-time issue or a pattern you've noticed?
```

### Step 2: Analyze Recent Work

Review the context to identify the root cause:

1. **Recent commits**: Use `git log -5 --oneline` to see recent changes
2. **Recent conversation**: Review the last 10-20 interactions for decision points
3. **Tool usage**: Identify which tools were used and how
4. **Guidelines consulted**: Check if relevant guidelines exist in AGENTS.md or development-principles.md

Ask yourself:
- Was there an existing guideline I violated?
- Was there an existing guideline that was unclear?
- Is there a missing guideline that should exist?

### Step 3: Identify Root Cause Category

Classify the issue into one of these categories:

**A. Guideline Violation**: Existing rule was not followed
- Example: "I didn't run tests before committing despite AGENTS.md requiring it"
- Action: Reinforce the existing guideline with emphasis or examples

**B. Unclear Guideline**: Rule exists but is ambiguous or incomplete
- Example: "AGENTS.md says 'use appropriate error handling' but doesn't specify what that means in this context"
- Action: Clarify the guideline with specific examples or criteria

**C. Missing Guideline**: No rule exists for this scenario
- Example: "There's no guidance on when to use Task tool vs. direct Grep"
- Action: Add a new guideline to prevent future occurrence

**D. Conflicting Guidelines**: Multiple rules give contradictory guidance
- Example: "DRY principle conflicts with 'avoid premature abstraction' in this case"
- Action: Clarify priority or add context for when each applies

### Step 4: Propose Guideline Update

Based on the root cause, draft an update to either:
- **`docs/development-principles.md`**: For general development principles (TDD, SOLID, error handling, etc.)
- **`AGENTS.md`**: For agent-specific workflows, tool usage, or project-specific patterns

**Update Principles**:

1. **Be specific**: Instead of "handle errors properly", write "use try/catch blocks for all external command execution"
2. **Include examples**: Show both good and bad examples when helpful
3. **State when to apply**: If the rule has exceptions, state them clearly
4. **Keep it concise**: One clear principle is better than verbose explanation
5. **Use imperative form**: "Always X" not "We should X" or "It's good to X"

**Template for new guideline**:
```markdown
### [Category]: [Brief Title]

**Issue**: [What problem this addresses]

**Guideline**: [Clear, actionable rule]

**Example**:
```
[Good example]
```

**Anti-pattern**:
```
[What to avoid]
```

**When to apply**: [Context or conditions]
```

### Step 5: Present and Apply Update

1. **Show the proposed change**:
   - Display the exact text to be added/modified
   - Explain which file will be updated (development-principles.md or AGENTS.md)
   - Explain the rationale

2. **Get user approval**:
   - Ask: "Does this guideline update capture the lesson correctly?"
   - Allow user to refine the wording or suggest changes

3. **Apply the update**:
   - Use Edit tool to update the appropriate file
   - Commit the change with message: `docs: add guideline for [topic] based on retrospective`

4. **Confirm learning**:
   - Summarize: "I've updated [file] to include [guideline]. I'll follow this going forward."

## Examples

### Example 1: Missing Test Coverage

**User**: "I'm not happy that you didn't write tests for the new function."

**Claude Response**:
```
I understand - test coverage is important. Let me analyze what happened:

Looking at the recent commit, I added `Initialize-WslDevContainer` but only wrote tests
after you prompted me.

Checking AGENTS.md... I see "All PowerShell code must include Pester tests" but I
violated this by committing code without tests first.

Root cause: Guideline violation (I didn't follow TDD)

I should strengthen the TDD guideline in development-principles.md to emphasize
NEVER committing code without tests. Should I add:

"### Test-Driven Development: Mandatory Test-First Workflow

**Guideline**: NEVER commit implementation code without corresponding tests.
Tests must be written BEFORE implementation (Red-Green-Refactor).

**Workflow**:
1. Write failing test
2. Run test to confirm it fails
3. Implement minimum code to pass
4. Run test to confirm it passes
5. Commit test and implementation together

**Violation prevention**: Before any git commit, run `.\test\bin\testrunner.ps1 -Unit`
to verify all tests pass."

Does this capture the lesson correctly?
```

### Example 2: Unclear Tool Selection

**User**: "Why did you use Grep directly instead of the Task tool like AGENTS.md suggests?"

**Claude Response**:
```
You're right to question this. Let me review the guidance:

AGENTS.md says "use Task tool with subagent_type=Explore for open-ended searches"
but you asked "find files handling authentication" which felt specific enough for Grep.

Root cause: Unclear guideline (boundary between "specific search" and "open-ended search" is ambiguous)

I should clarify the guideline in AGENTS.md with concrete examples:

"### When to Use Task Tool vs. Direct Search

**Use Task tool (Explore agent)** when:
- Question requires understanding code patterns: 'How does authentication work?'
- Multiple search rounds likely needed: 'Where are errors handled?'
- Need to connect information across files: 'What's the codebase structure?'

**Use Grep/Glob directly** when:
- Searching for specific string/pattern: 'Find all uses of MyFunction'
- Single search likely sufficient: 'Find config files'
- You know exactly what to search for

**When in doubt**: Use Task tool - it's better to over-use exploration than miss context."

Should I add this clarification to AGENTS.md?
```

## Guidelines for Effective Retrospectives

1. **Focus on systems, not blame**: The goal is to improve guidelines, not criticize past decisions
2. **Be specific**: Vague lessons like "be more careful" don't prevent future issues
3. **Update quickly**: Make the change while context is fresh
4. **Test the guideline**: After updating, verify the new guideline would have prevented the issue
5. **Iterate**: If the same issue recurs, the guideline needs further refinement

## File Decision Matrix

**Update `development-principles.md`** for:
- General software engineering principles (TDD, SOLID, DRY)
- Error handling patterns
- Testing strategies
- Code quality standards
- Platform-agnostic best practices

**Update `AGENTS.md`** for:
- Project-specific workflows
- Tool usage patterns (Task, Grep, Edit, etc.)
- Environment-specific behavior (CI vs. interactive)
- Integration patterns (Scoop, Keypirinha, etc.)
- Commit and PR creation workflows

**Update both** when:
- The principle is general (development-principles.md) but needs project-specific application (AGENTS.md)
- Example: TDD principle lives in development-principles.md, but "run testrunner.ps1 before commits" lives in AGENTS.md
