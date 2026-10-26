# px-proxy traces

Where each [px-proxy requirement](../requirements/px-proxy.md) is implemented and tested, and whether its tests passed. The implementation and test needs come from [codelinks](https://sphinx-codelinks.useblocks.com/) markers in the PowerShell source: a `<# @need <type>: <title> ... @endneed #>` block above a function or a Pester `It`, naming its `:id:` and the requirements it `:implements:` or `:tests:`. A test's title is its Pester path, `Describe.It`, which its result in the [test results](../test-results.md) is matched on.

A test's status is the worst of its results, and *not run* when it has none; its card below links the results. A requirement's status is the worst status of its tests. Worst first: failed, error, passed, skipped, disabled, not run.

```{needtable}
:types: req
:columns: id, title, verdict as "Status", implements_back as "Implemented by", tests_back as "Tested by"
:style: table
```

## Implementation

```{src-trace}
:project: px-proxy
```

## Tests

```{needtable}
:types: test
:columns: id, title as "Pester path", verdict as "Status", tests as "Tests"
:style: table
```

```{src-trace}
:project: px-proxy-tests
```
