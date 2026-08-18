# `prodserver.mcp.schema`
```MATLAB
definitions = schema(fcns, tests, opts)
```
Generate MCP tool schemas by observing function calls at runtime. Creates shadow wrappers that intercept calls to the specified functions, runs the provided tests, records argument types as JSON Schema fragments, then merges them into complete tool definitions compatible with `prodserver.mcp.build`.

The returned `definitions` struct is directly usable as:
```MATLAB
prodserver.mcp.build(fcns, definition=definitions)
```

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| fcns | string | Name(s) of functions to observe. Must be on the MATLAB path. | "schemaCompute" |
| tests | function_handle, string, or cell | Test specification to run. Accepts function handles, .m file paths, folder paths, function/script names, or cell arrays combining these. All tests run sequentially. | @() myFunc(1,2) |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| definitions | struct | MCP tool definitions with `tools` and `signatures` fields. Directly usable as `build(fcns, definition=definitions)`. | struct |

### Optional Inputs (Name/Value pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `encoding="JSON"`.
| Argument | Type | Description | Default | Example |
| :---     | :--- | :---        | :---    |:---     |
| typemap | struct | Map of MATLAB type names (fieldnames) to JSON type names (values). Overrides default type mappings. | [] | struct('uint64','integer') |
| encoding | WireEncoding | Wire encoding strategy: "Invertible", "JSON", or "Hybrid". | "Invertible" | "JSON" |

All functions in `fcns` must be called at least once during test execution. If a function is never called, `schema` raises an error. For functions without argument blocks, parameter requiredness is inferred from the minimum observed argument count across all test calls. Name-value pair arguments appear in the schema only if the tests use them.

See [Schemas](./Schemas.md) for conceptual background on schema generation approaches.

# Examples

Generate a schema for `schemaCompute` by exercising it with known inputs:
```MATLAB
defs = prodserver.mcp.schema("schemaCompute", ...
    @() schemaCompute(1.0, 2.0, 3.0, scale=2.0, label="test"));
```

***

Generate schemas for two functions using a single test that exercises both:
```MATLAB
defs = prodserver.mcp.schema(["toyScalarOne","toyScalarTwo"], ...
    @() exerciseBoth());
```
where `exerciseBoth` is:
```MATLAB
function exerciseBoth()
    [~] = toyScalarOne(42.0);
    [~,~] = toyScalarTwo("hello", 3.0);
end
```

***

Generate schemas and build in one step using the `tests` option of `build`:
```MATLAB
ctf = prodserver.mcp.build("schemaCompute", ...
    tests=@() schemaCompute(1.0, 2.0, 3.0, scale=2.0), ...
    server="http://localhost:9910");
```

***

Provide multiple test exercises as a cell array to communicate which parameters are optional. Here, parameters 3-5 are optional because the minimum call uses only 2 arguments:
```MATLAB
defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
    {@() schemaFlexNoBlock(1,2), ...
     @() schemaFlexNoBlock(1,2,3,4,5)});
```

***

Run a test file to exercise the target function:
```MATLAB
defs = prodserver.mcp.schema("myTool", "test/myToolTests.m");
```

--- Copyright 2026 The MathWorks, Inc. ---
