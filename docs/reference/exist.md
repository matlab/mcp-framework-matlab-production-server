# `prodserver.mcp.exist`
```MATLAB
tf = exist(endpoint, identifier, type)
```
Check whether a tool or resource exists on the MCP server at `endpoint`. For tools, `identifier` is the tool name. For resources, `identifier` is the resource URI. `identifier` may be a vector to check multiple items at once, but `type` must be a single string. The output `tf` is the same size as `identifier`.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | `"http://localhost:9910/primeSequence/mcp"` |
| identifier | string | Tool name or resource URI. Scalar or vector. | `"primeSequenceMCP"` or `"mcp://materials/aluminum_6061"` |
| type | Primitive | Type of MCP primitive. Scalar or same size as `identifier`. | `"Tool"` or `"Resource"` |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| tf | logical | Does the MCP primitive exist? Same size as `identifier`. | `true` or `[true false true]` |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds to pause between retries. | 2 |
| retry | integer | Number of times to retry on HTTP protocol errors (404, for example). | 10 | 
| timeout | integer | Number of seconds to wait for a reply. | 30 |

# Examples

Check whether a tool exists:
```MATLAB
tf = prodserver.mcp.exist("http://localhost:9910/primeSequence/mcp", ...
    "primeSequenceMCP", "Tool")
```

Check multiple tools at once:
```MATLAB
tf = prodserver.mcp.exist("http://localhost:9910/primeSequence/mcp", ...
    ["toolOne", "toolTwo", "toolThree"], "Tool")
```
The return value `tf` is a three-element logical vector. `tf(1)` indicates the existence of `toolOne`, `tf(2)` the existence of `toolTwo`, and `tf(3)` the existence of `toolThree`.

Check whether a resource exists by URI:
```MATLAB
tf = prodserver.mcp.exist(endpoint, ...
    "mcp://protocol/tools/wire-format/parameters/encoding_rules", "Resource")
```

--- Copyright 2025-2026 The MathWorks, Inc. ---
