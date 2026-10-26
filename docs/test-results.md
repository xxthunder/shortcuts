# Test results

The results of the last Pester run, read from `test/out/junit.xml` as Pester writes it: one need per test file and one per test case. A result of a traced test links the test it resulted from, by its name: the test's title is its Pester path, `Describe.It`. Where a tool's requirements and tests meet their results, its traces page shows it, such as [px-proxy's](traceability/px-proxy.md).

The documentation build in CI reads the report of the test run before it. A local build without a test run first has no report: it shows every test as not run.

```{test-file} Pester results
:file: test/out/junit.xml
:id: TESTFILE_PESTER
:auto_suites:
:auto_cases:
:collapse: TRUE
```
