# px-proxy traces

Where each [px-proxy requirement](../requirements/px-proxy.md) is implemented and tested. The implementation and test needs come from [codelinks](https://sphinx-codelinks.useblocks.com/) markers in the PowerShell source: a `<# @need <type>: <title> ... @endneed #>` block above a function or a Pester `It`, naming its `:id:` and the requirements it `:implements:` or `:tests:`.

```{needtable}
:types: req
:columns: id, title, implements_back as "Implemented by", tests_back as "Tested by"
:style: table
```

## Implementation

```{src-trace}
:project: px-proxy
```

## Tests

```{src-trace}
:project: px-proxy-tests
```
