---
name: tdd-workflow
description: Guide test-driven development workflow. Use when: (1) Implementing new features or functions, (2) Modifying existing functions, (3) Fixing bugs, (4) Refactoring code. This skill provides the Red-Green-Refactor cycle workflow and ensures tests and implementation are always committed together.
---

# TDD Workflow

Step-by-step test-driven development workflow following Red-Green-Refactor principles.

## The Red-Green-Refactor Cycle

### RED: Write a Failing Test

1. Write a test that describes the desired behavior
2. Run the test - it should FAIL (red)
3. Verify the failure is for the right reason

### GREEN: Make the Test Pass

1. Write the minimum code needed to pass the test
2. Run the test - it should PASS (green)
3. Don't worry about code quality yet

### REFACTOR: Improve the Code

1. Clean up the code while keeping tests passing
2. Remove duplication (DRY)
3. Improve readability
4. Run tests frequently during refactoring

## Workflow Steps

### For New Features

1. **Write the test** (RED phase)
   - Create a test that describes the desired behavior
   - Use the project's testing framework conventions

2. **Run tests - confirm failure** using the project's test execution skill (unit tests)
   - Expected: Test fails because the function/method doesn't exist yet

3. **Implement minimal code** (GREEN phase)
   - Write the minimum code needed to make the test pass
   - Don't optimize or add extras yet

4. **Run tests - confirm pass** using the project's test execution skill (unit tests)
   - Expected: Test passes

5. **Refactor if needed** (REFACTOR phase)
   - Improve implementation
   - Add error handling
   - Remove duplication
   - Keep tests passing

6. **Commit test + implementation together**
   ```bash
   git add src/module.ext test/module.test.ext
   git commit -m "feat: add new-feature function"
   ```

### For Modifying Existing Functions

**CRITICAL: Never modify implementation without updating tests!**

1. **Read existing tests**
   - Understand what behavior is currently tested
   - Identify gaps in test coverage

2. **Update tests for new behavior** (RED phase)
   - Add a test case for the new behavior or parameter

3. **Run tests - confirm failure** using the project's test execution skill (unit tests)
   - Expected: New test fails, existing tests pass

4. **Update implementation** (GREEN phase)
   - Modify the function to satisfy the new test

5. **Run tests - confirm all pass** using the project's test execution skill (unit tests)
   - Expected: All tests pass (old and new)

6. **Commit test + implementation together**
   ```bash
   git add src/module.ext test/module.test.ext
   git commit -m "feat: add new-parameter to existing-function"
   ```

### For Bug Fixes

1. **Write test that reproduces the bug** (RED phase)
   - Create a test that exercises the failing edge case

2. **Run test - confirm it fails**
   - Test should fail, demonstrating the bug

3. **Fix the bug** (GREEN phase)
   - Modify implementation to pass the new test
   - Ensure existing tests still pass

4. **Run all tests** using the project's test execution skill (unit tests)

5. **Commit test + fix together**
   ```bash
   git add src/module.ext test/module.test.ext
   git commit -m "fix: handle edge case in function-with-bug"
   ```

## Running Tests

Use the project's test execution skill for all test execution — unit tests, integration tests, coverage, and specific test files. The test execution skill knows the project-specific commands and options.

## TDD Best Practices

1. **Write the smallest test possible** - Test one behavior at a time
2. **See it fail first** - Never skip the RED phase
3. **Write minimal code** - Only enough to pass the test
4. **Refactor with confidence** - Tests protect against regressions
5. **Keep tests fast** - Mock external dependencies in unit tests
6. **Test behavior, not implementation** - Focus on what, not how
7. **One assertion per test** - Each test verifies one thing
8. **Commit tests and implementation together** - They are inseparable

## Common Mistakes to Avoid

1. **Skipping the RED phase** - Writing tests after implementation
2. **Committing implementation without tests** - Tests must be in same commit
3. **Committing tests without implementation** - Implementation must be in same commit
4. **Not running tests before committing** - All tests must pass
5. **Testing implementation details** - Test public interface, not internals
6. **Writing too much code** - Implement only what's needed to pass tests
7. **Ignoring failing tests** - All tests must pass before proceeding

## Integration with Test Execution Skill

For detailed testing execution guidance, use the project's test execution skill:
- Available test commands and options
- CI/CD integration patterns
- Troubleshooting test failures
- Advanced testing features
