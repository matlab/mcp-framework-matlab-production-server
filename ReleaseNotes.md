# 1.5.0: Oct. 2026
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

# 1.1: Dec. 2, 2025
* Build multiple tools into a single MCP server
* Automatic generation of MCP tool description from function comments and argument blocks
* Automatically externalize non-scalar inputs and outputs
* Specify `ImportOptions` objects to deserialize externalized inputs
* Support for optional inputs and outputs in automatically generated wrapper functions
* Handwritten wrapper functions still supported (and will remain supported for the foreseeable future)

# 1.0: Nov 7, 2025
Initial release. Features:
* Create MCP server containing one MCP tool
* Handwritten MCP tool description required
* Externalizing large inputs and outputs via handwritten wrapper functions

--- Copyright 2025-2026 The MathWorks, Inc. ---
