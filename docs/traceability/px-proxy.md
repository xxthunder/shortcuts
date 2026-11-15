# px-proxy traces

Where each [px-proxy requirement](../requirements/px-proxy.md) is implemented and tested, and whether its tests passed. How traces and statuses are read is explained in [How a trace is read](../test-results.md#how-a-trace-is-read).

```{needtable}
:types: req
:filter: id.startswith("REQ_PX")
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
:filter: id.startswith("TEST_PX")
:columns: id, title as "Pester path", verdict as "Status", tests as "Tests"
:style: table
```

```{src-trace}
:project: px-proxy-tests
```
