# Test results

The results of the last Pester run, read from `test/out/junit.xml` as Pester writes it: one need per test file and one per test case. A result of a traced test links the test it resulted from, by its name. Where a tool's requirements and tests meet their results, its traces page shows it, such as [px-proxy's](traceability/px-proxy.md) and [update-scoop's](traceability/update-scoop.md).

The documentation build in CI reads the report of the test run before it. A local build without a test run first has no report: it shows every test as not run.

## How a trace is read

The implementation and test needs on a traces page come from [codelinks](https://sphinx-codelinks.useblocks.com/) markers in the PowerShell source: a `<# @need <type>: <title> ... @endneed #>` block above a function or a Pester `It`, naming its `:id:` and the requirements it `:implements:` or `:tests:`. A test's title is its Pester path, `Describe.It`, which its result here is matched on.

A test's status is the worst of its results, and *not run* when it has none; its card links the results. A requirement's status is the worst status of its tests. Worst first: failed, error, passed, skipped, disabled, not run.

```{test-file} Pester results
:file: test/out/junit.xml
:id: TESTFILE_PESTER
:auto_suites:
:auto_cases:
:collapse: TRUE
```
