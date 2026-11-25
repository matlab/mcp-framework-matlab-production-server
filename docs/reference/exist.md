# `prodserver.mcp.exist`
```MATLAB
tf = exist(endpoint, identifier, type)
```
Check whether a tool or resource exists on the MCP server at `endpoint`. For tools, `identifier` is the tool name. For resources, `identifier` is the resource URI. `identifier` may be an array to check multiple items at once. `type` is a single primitive type that applies to every identifier, or an array the same size as `identifier`. Any other size raises `prodserver:mcp:SizeMismatch`. The output `tf` is the same size as `identifier`.

A name or URI the server lists more than once exists, so `tf` is `true` for it. [`call`](./call.md) and [`read`](./read.md) still refuse it, with `prodserver:mcp:NonUniqueTool` or `prodserver:mcp:NonUniqueResource`.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | `"http://localhost:9910/primeSequence/mcp"` |
| identifier | string | Tool name or resource URI. Scalar or vector. | `"primeSequence"` or `"mcp://materials/aluminum_6061"` |
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
| protocol | string | MCP revision: `"discover"` asks the server, `"2025-06-18"` or `"2026-07-28"` uses that one. See [Protocol Revision](#protocol-revision). | `"discover"` |
| retry | integer | Number of times to resend a request that gets HTTP 408 or 429, or Production Server's 404 for an archive it doesn't have or is still deploying. See [An Archive That Answers 404](./call.md#an-archive-that-answers-404). A refused connection or a timeout is resent once, whatever `retry` is. | 30 |
| timeout | integer | Number of seconds to wait for each reply. | 60 |

### Protocol Revision

With the default `protocol="discover"`, the function picks the revision as [`call`](./call.md#protocol-revision) does: it probes with `server/discover`, falls back to `2025-06-18`, and remembers the answer for each endpoint. If the request fails with `prodserver:mcp:RemoteError`, `prodserver:mcp:HttpError`, `prodserver:mcp:UnattributableRequest`, `prodserver:mcp:NoSessionFromServer` or `prodserver:mcp:MethodNotFound`, it forgets the answer, probes again and retries once. `prodserver:mcp:UnknownArchive` isn't one of them: no revision changes it.

Naming a revision skips the probe and the retry. The function also remembers that revision for the endpoint, so later calls that use `"discover"`, including `call`, use it too. Any value other than the three above raises `prodserver:mcp:UnsupportedProtocolVersion`. That includes the aliases `2025-03-26` and `2024-11-05`, which the server accepts but the client doesn't.

# Examples

Check whether a tool exists:
```MATLAB
tf = prodserver.mcp.exist("http://localhost:9910/primeSequence/mcp", ...
    "primeSequence", "Tool")
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
