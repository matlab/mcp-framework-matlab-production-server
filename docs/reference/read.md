# `prodserver.mcp.read`
```MATLAB
result = read(endpoint, uri)
```
Read one or more resources from the MCP server at `endpoint`. Each element of `uri` must match a resource URI returned by `list(endpoint, "Resource")`.

Text resources return as a string array by default. If any resource is binary, the result is a cell array.

### Inputs
| Argument | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| endpoint | string | Network endpoint of MCP server. | `"http://localhost:9910/myTool/mcp"` |
| uri | string | Resource URI (scalar or vector). | `"mcp://materials/aluminum_6061"` |

### Outputs
| Argument | Type | Description |
| :--- | :--- | :--- |
| result | string or cell | String array when all resources are text. Cell array otherwise. |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=30`.

| Argument | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| TextAsString | logical | Return text resources as a string array. Set to `false` to always return a cell array. | `true` |
| timeout | integer | Seconds to wait for a reply. | 60 |
| retry | integer | Number of retries on HTTP errors. | 3 |
| delay | integer | Seconds between retries. | 2 |

# Examples

List resources, then read one by URI:
```MATLAB
resources = prodserver.mcp.list(endpoint, "Resource");
result = prodserver.mcp.read(endpoint, resources{1}.uri);
```

Read a known resource URI directly:
```MATLAB
rules = prodserver.mcp.read(endpoint, ...
    "mcp://protocol/tools/wire-format/parameters/encoding_rules");
```

--- Copyright 2026 The MathWorks, Inc. ---
