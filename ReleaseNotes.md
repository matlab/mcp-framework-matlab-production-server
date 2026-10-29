# 1.6: Oct. 2026
Servers support two MCP revisions: `2025-06-18`, which uses sessions, and `2026-07-28`, which is stateless and adds `server/discover`. Each request is served by the revision it is written for. Under `2026-07-28`, list results carry `ttlMs` and `cacheScope` cache hints. See [Protocol Conformance](./docs/concepts/protocol-conformance.md) and, for the cache hints, [Security](./docs/concepts/security.md#cached-list-results).

Changes from 1.5.0 behavior:
* **`MCP-Protocol-Version`, if sent, may be `2025-06-18` or `2026-07-28`**, or `2025-03-26` or `2024-11-05`, which are served as `2025-06-18`. Any other value gets HTTP 400 with error `-32022`, which lists the supported versions. `2026-07-28` requests must send the header, and it must match the version in the request's `_meta`.
* **`2026-07-28` requests have no session.** Instead of `Mcp-Session-Id` they carry `_meta` and the `Mcp-Method` header, plus `Mcp-Name` for methods that name a tool, resource or prompt. A missing or mismatched header gets HTTP 400. `Mcp-Session-Id`, `initialize`, and `prodserver.mcp.call` ending its session on error apply to `2025-06-18` only.
* **`build` with `example` builds no wrapper**, so large arguments are passed by value. In 1.5.0 the wrapper was built into the archive but never called. Combining `example` with a `wrapper` other than `"Auto"` or `"None"` raises `prodserver:mcp:ExampleWrapperConflict`. See [Wrapper Functions](./docs/concepts/wrapper-functions.md).
* **`listChanged` is `false`.** The tool and resource lists are fixed when the archive is built, and a JSON-only server has no stream to send change notifications on.
* **Not every error is HTTP 200.** Internal errors are still HTTP 500 with `-32603`. Malformed JSON (`-32700`) and invalid requests (`-32600`), including batches and bodies that aren't JSON objects, return HTTP 400. Under `2026-07-28`, an unknown method returns HTTP 404.
* **`DELETE` without a session returns HTTP 405**, not 400, with `Allow: POST, DELETE`. Under `2026-07-28` every `DELETE` returns 405 with `Allow: POST`.
* **`resources/read` of an unknown URI returns `-32602` under `2026-07-28`**, which may not use `-32002`. `2025-06-18` still returns `-32002`.
* **`resources/templates/list` returns an empty `resourceTemplates` list** instead of error `-32601`. `prompts/list` still returns `-32601`.
* **A request body with no `Content-Type` returns HTTP 415.** 1.5.0 read it as `application/json`. An empty body returns `-32600`.
* **Tool-error text no longer starts with a MATLAB source location.** A tool that raises returns its error message alone in the `isError` result, without the `file:line : ` prefix 1.5.0 added. JSON-RPC error messages still have the prefix.
* **`serverInfo.title` is the archive name**, not `MATLAB Production Server`. It is left out for clients that request `2024-11-05`.
* **The server checks `tools/call` arguments against the tool's `inputSchema`** before running the tool. Under `2025-06-18` an invalid argument gets error `-32602`; under `2026-07-28` it gets a tool result with `isError` and the text `Input validation error: ...`.
* **The `Hybrid` wire encoding is removed.** `WireEncoding` has only `JSON` and `Invertible`, and `encoding="Hybrid"` raises an error.
* **Under `encoding="Invertible"`, a parameter that may be a scalar is published as an `anyOf`** of its bare forms and the wrapper. The wrapper's `type` is an `enum` of the classes the parameter accepts. The wrapper's `data` is always an array: a string scalar is sent with `data` `["hello"]`, though the old form is still accepted. See [Wire Encoding](./docs/concepts/wire-encoding.md#published-schemas).
* **Plain JSON encoding decodes `datetime` and `duration` arguments.** ISO 8601 text that the schema marks `date-time` becomes a `datetime`, and seconds that it marks `duration` become a `duration`. Text that isn't a date-time is rejected as an invalid argument. `prodserver.mcp.call` decodes outputs the same way.

Other changes:
* `prodserver.mcp.call`, `list`, `read` and `exist` detect the server's revision, remember it for each endpoint, and retry once after a protocol error. `list`, `read` and `exist` take a `protocol` option that names the revision instead. See [`call`](./docs/reference/call.md#protocol-revision).
* New metric `MCP_<tool>_Call_<revision>` counts tool calls under each revision. See [Server Metrics](./docs/guides/server-metrics.md).
* New metrics `MCP_<tool>_Rejected` and `MCP_<tool>_Rejected_<revision>` count tool calls the server refuses before running the tool. A call rejected for invalid arguments counts as `_Rejected`, not `_Call`.
* `deploy`, and `build` with `server`, wait until the archive answering `ping` is the build they uploaded, named by the `MATLAB-MCP-Archive-UUID` header from the `.ctf` file's UUID. If the old build is still answering when verification runs out, they raise `prodserver:mcp:DeployedArchiveStale`. For archives built earlier, they ask `/api/discovery` (for at most 10 seconds) or accept any `pong`. See [`deploy`](./docs/reference/deploy.md).
* The `/api/discovery` description of an MCP archive ends with `MCP-Versions:` and the revisions it supports. See [Discovery](./docs/concepts/discovery.md).
* The `build` option `maxLiteralSize` sets the largest argument a generated wrapper passes by value. It used to be ignored in favor of a fixed 64. `typemap` now applies to every generated description. See [`build`](./docs/reference/build.md).
* `build` accepts one `wrapper` keyword (`"Auto"`, `"None"` or `""`) for several functions. A `wrapper` list of the wrong length raises `prodserver:mcp:SizeMismatch` instead of an index error.
* `exist` accepts an array of identifiers, with one `type` or one per identifier.
* `metrics` accepts a plain server address, such as `http://localhost:9910`, for every scope except `Scope.Server`.
* `serverInfo.version` now reports the framework release (1.6.0). 
* Binary resources: `blob` is now Base64-encoded on the wire, as MCP requires; before, the bytes were sent as a JSON array of numbers. `prodserver.mcp.read` returns binary resources as a `uint8` row vector. Clients from 1.5 or earlier, and any client that relied on the number array, receive Base64 text instead. Give binary resource contents as raw `uint8` bytes, not Base64. Raw bytes with no `mimeType` get `application/octet-stream`; before, reading them raised an error.
* File resources whose `mimeType` is `application/json` or another text type are read as UTF-8 text, not bytes.
* Under `encoding="Invertible"`, a missing string or undefined categorical element is sent as `null` in `data`, not `[null]`. The old form is still accepted. An undefined categorical scalar, which failed to decode, now decodes.
* Externalized arguments accept `file:///` URIs (`file:///tmp/x.mat`, `file:///C:/x.mat`), the form the tool descriptions advertise, and arrays of file URIs. `json:` locations work through `prodserver.mcp.io.MarshallURI`. Server addresses with an empty host, such as `http:///mcp`, are rejected.
* The `read_mcp_resource` tool takes `uri` and raises an error for an unknown URI, as in 1.5.0. In 1.4 it took `url` and returned empty text.

# 1.5: Oct. 2026
Servers now conform to MCP revision `2025-06-18`. See [Protocol Conformance](./docs/concepts/protocol-conformance.md).

Breaking changes for clients other than `prodserver.mcp.call`:
* **Protocol errors are JSON-RPC `error` objects.** Malformed requests, unknown methods, unknown tools and bad parameters used to return `result.isError`. They now return an `error` member with a numeric code and no `result`. `result.isError` now means only that a tool ran and raised.
* **Internal server errors return HTTP 500** with code `-32603`. Every other error is HTTP 200.
* **`Mcp-Session-Id` is required** on every request except `initialize` and notifications, including `DELETE`. Without it, the server answers HTTP 400.
* **`MCP-Protocol-Version` must be `2025-06-18`** if sent. Any other value gets HTTP 400.
* **`initialize` always reports `2025-06-18`** instead of echoing the client's requested version.
* **`resources/read` of an unknown URI returns error `-32002`** instead of HTTP 204.
* **`prompts/list` and `resources/templates/list` return error `-32601`** instead of HTTP 204.
* **Requests to `/<archive>/sse` return HTTP 404.**

Other changes:
* Verbs other than `POST` and `DELETE` return HTTP 405 with an `Allow` header.
* An `Accept` header that rules out JSON returns HTTP 406.
* Notifications always return HTTP 202 with no body.
* A missing `Content-Type` request header is read as `application/json`.
* `Content-Type` matching ignores case and parameters, so `application/json; charset=utf-8` and `Application/JSON` are decoded as JSON. They used to get error `-32700`.
* A `Content-Type` other than `application/json` returns HTTP 415. It used to get error `-32700`.
* A batch holding one request returns error `-32600`, as larger batches do, and the request doesn't run. It used to run as if it had been sent alone. An empty batch, `[]`, also returns `-32600` instead of `-32700`.
* A body that is valid JSON but not an object, such as `42`, `"str"`, `true` or `null`, returns error `-32600`. It used to get `-32700`, which says the JSON is malformed.
* When a tool's `arguments` block rejects an input, the error names the right argument position. It used to name the position after it.
* Tools with no inputs can be called.
* `prodserver.mcp.call` returns outputs in a defined order and raises `TooFewOutputs` or `MissingOutputs` instead of an indexing error. A call written as a statement returns its result in `ans`. See [`call`](./docs/reference/call.md#outputs).
* `prodserver.mcp.call` raises `prodserver:mcp:ToolError`, with the tool's error text, when the tool raises. It used to raise `NoStructuredContent` or return the error text as the tool's output.
* `prodserver.mcp.call` ends its MCP session when it raises an error.
* `prodserver.mcp.deploy` reports a rejected upload immediately, with the server's explanation, and doesn't retry a 4xx. See [`deploy`](./docs/reference/deploy.md#upload-failures).
* A server that can't load its tool definitions returns error `-32603` with the reason, instead of a bare load error. When the cause is a framework class clash between archives in one worker, the message says to set `MW_MULTIMCOS_MODE`. The server tries the load again on the next request. See [Several Archives on One Server](./docs/reference/deploy.md#several-archives-on-one-server).
* `prodserver.mcp.build` works when the framework is installed in a read-only folder. If it can't make its copy of a template writable, it raises `prodserver:mcp:FileNotWritable` with the reason.
* `Catalog.filter` and `Catalog.archive` accept `suffix`, to select metrics by deployment. For example, `suffix=@max` selects the most recent deployment of an archive. See [`metrics`](./docs/reference/metrics.md#the-suffix-argument).

# 1.4: Sept. 2026
* MCP Resources fully supported.
* Metrics & Observability
* Integration with MPS discovery API
* Argument blocks now optional. Tool description can be generated via function "examples"
* Improved documentation
* AI agent skills for tool building and deployment.

# 1.3: Jun. 2026
* build() method supports additional files
* Allow server address without port number

# 1.2: Jan. 2026
* Support for optional positional arguments
* Allow external and literal arguments in the same parameter list

# 1.1: Dec. 2025
* Build multiple tools into a single MCP server
* Automatic generation of MCP tool description from function comments and argument blocks
* Automatically externalize non-scalar inputs and outputs
* Specify `ImportOptions` objects to deserialize externalized inputs
* Support for optional inputs and outputs in automatically generated wrapper functions
* Handwritten wrapper functions still supported (and will remain supported for the foreseeable future)

# 1.0: Nov. 2025
Initial release. Features:
* Create MCP server containing one MCP tool
* Handwritten MCP tool description required
* Externalizing large inputs and outputs via handwritten wrapper functions

--- Copyright 2025-2026 The MathWorks, Inc. ---
