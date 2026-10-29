# `prodserver.mcp.read`
```MATLAB
result = read(endpoint, uri)
```
Read one or more resources from the MCP server at `endpoint`. Each element of `uri` must match a resource URI returned by `list(endpoint, "Resource")`.

Text resources return as a string array by default. If any resource is binary, the result is a cell array, and each binary resource is a `uint8` row vector of its bytes. The server sends binary content Base64-encoded in `blob`, as MCP requires; `read` decodes it, so you never see the Base64 text. A resource is text if its `mimeType` is `text/*`, `application/json` or another text type.

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
| protocol | string | MCP revision: `"discover"` asks the server, `"2025-06-18"` or `"2026-07-28"` uses that one. See [Protocol Revision](#protocol-revision). | `"discover"` |
| timeout | integer | Seconds to wait for each reply. | 60 |
| retry | integer | Number of times to resend a request that gets HTTP 404, 408 or 429. A refused connection or a timeout isn't retried. | 3 |
| delay | integer | Seconds between retries. | 2 |

### Protocol Revision

With the default `protocol="discover"`, the function picks the revision as [`call`](./call.md#protocol-revision) does: it probes with `server/discover`, falls back to `2025-06-18`, and remembers the answer for each endpoint. If the request fails with `prodserver:mcp:RemoteError`, `prodserver:mcp:HttpError`, `prodserver:mcp:UnattributableRequest`, `prodserver:mcp:NoSessionFromServer` or `prodserver:mcp:MethodNotFound`, it forgets the answer, probes again and retries once.

Naming a revision skips the probe and the retry. The function also remembers that revision for the endpoint, so later calls that use `"discover"`, including `call`, use it too. Any value other than the three above raises `prodserver:mcp:UnsupportedProtocolVersion`. That includes the aliases `2025-03-26` and `2024-11-05`, which the server accepts but the client doesn't.

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
