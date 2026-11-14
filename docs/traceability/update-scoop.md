# update-scoop traces

Where each [update-scoop requirement](../requirements/update-scoop.md) is implemented and tested, and whether its tests passed. How traces and statuses are read is explained in [How a trace is read](../test-results.md#how-a-trace-is-read). A requirement carried out by a wrapper with no marker, such as a `.bat`, names it under "Implemented in".

```{needtable}
:types: req
:filter: id.startswith("REQ_SCOOP")
:columns: id, title, verdict as "Status", implements_back as "Implemented by", implemented_in as "Implemented in", tests_back as "Tested by"
:style: table
```

## Implementation

```{src-trace}
:project: update-scoop
```

## Tests

```{needtable}
:types: test
:filter: id.startswith("TEST_SCOOP")
:columns: id, title as "Pester path", verdict as "Status", tests as "Tests"
:style: table
```

```{src-trace}
:project: update-scoop-tests
```

```{src-trace}
:project: update-scoop-wrapper-tests
```
