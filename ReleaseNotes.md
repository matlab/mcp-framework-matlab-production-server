# 1.7: Nov. 2026
MCP Apps: a tool can have an interactive view, which hosts that support MCP Apps show in the chat. Pass the view's HTML file to `build`'s new `app` option. See [MCP Apps](./docs/guides/mcp-apps.md). The [Signal Filter App](./Examples/SignalFilterApp/walkthrough.md) example builds one for `cleanSignal`, and shows how to write a view with an LLM.

Changes from 1.6 behavior:
* **`2025-06-18` session IDs carry the client's capabilities.** `initialize` returns a token of up to 1,024 characters instead of a UUID. Treat it as opaque, and send it back unchanged.
* **A `2025-06-18` session ID that isn't one of this server's tokens gets HTTP 404**, with error `-32001`, and isn't echoed back. That's an ID that is malformed, longer than 1,024 characters, or a UUID from a session opened before the server was upgraded: the client must send `initialize` again. The token isn't signed, so it identifies a session but doesn't authenticate the client. 1.6 accepted any non-blank session ID. See [Sessions](./docs/concepts/protocol-conformance.md#sessions).
* **The `/signature` route echoes only this server's session tokens.** It used to echo any value.
* **`/signature` describes a tool built with `example` from its arguments block and example calls.** A parameter's `type` is its declared class, or the classes the example calls passed, joined by `|`, or `""`; it used to be a guessed `"double"`. A parameter with no declared class is `""` in a tool built without `example` too. `validation` and `default` come from the arguments block; they used to be empty. See [Discovery](./docs/concepts/discovery.md).
* **A request `id` must be a string or an integer.** An object, array, boolean or fractional `id` gets `-32600`, HTTP 400; it used to be processed and echoed. An empty string, `""`, is now accepted as an `id`; it used to be rejected as missing.
* **`prodserver.mcp.agent.setup` no longer adds entries to Claude Code's configuration itself.** It registers the skill marketplace with `claude plugin marketplace add` only, and raises `prodserver:mcp:ClaudeInstallFailed` if that fails. 1.6 then wrote `known_marketplaces.json` itself, in a form Claude Code rejects as corrupted, which stopped every marketplace working. Running `setup` again repairs a file that 1.6 broke. If the marketplace is registered from another folder, such as an earlier clone, `setup` registers this copy in its place, and registers the old folder again if that fails. An entry 1.6 renamed to `mcp_framework_matlab_production_server` is replaced too. The toolbox now ships `.claude-plugin/marketplace.json`, without which the command always failed for an Add-Ons install. See [agent setup](./docs/reference/agent-setup.md#repairing-a-configuration-earlier-versions-broke).
* **A metrics `Scope` is a kind of metric, from every archive.** `Scope.Server` used to select names containing `_<archive>_` for the endpoint's archive, so archive `foo` took in `foo_bar`'s metrics, and missed its own tools'. It now selects each archive's `MCP_<archive>_Request` and `_ElapsedTime`, and no longer raises `prodserver:mcp:NoServerScope`. `Scope.Tool` now includes the `_Rejected`, `_Refused` and per-revision counters. The new `Scope.Framework` and `Scope.Custom` complete the set. `catalog.filter` accepts `scope`, so `catalog.filter(scope=prodserver.mcp.metrics.Scope.Tool, archive="foo")` selects one archive's metrics of one kind. See [`metrics`](./docs/reference/metrics.md#the-scope-argument).
* **Client errors and warnings no longer show the user information or query of an address.** An endpoint such as `http://alice:secret@host:9910/x/mcp` appeared in messages as given, password included. Messages from `call`, `list`, `read`, `exist`, `metrics` and `deploy`, and from the address validators, now show `http://host:9910/x/mcp`; a query is removed too, with a note that it was.
* **An archive name may contain only letters, digits and `_`.** `build` and `deploy` raise `prodserver:mcp:InvalidArchiveName` for any other, before building or sending anything. A hyphen used to fail in MATLAB Compiler, and other characters deep in `matlab.net.http`, with errors that didn't name the archive.
* **`Framework` is no longer an archive name.** The framework's own request counter is `MCP_Framework_Request`, the name an archive called `Framework` would give its own, so MPS reported the two as one metric, counting every request twice. `build` and `deploy` raise `prodserver:mcp:InvalidArchiveName` for it.
* **Plain JSON sends an output's `Inf` and `-Inf` as text, and refuses them in arguments.** `jsonencode` writes them as `null`, as it does NaN, so they used to arrive as NaN with no warning. A tool's output, or an array element of one, or a struct field its schema describes, now sends them as `"Inf"` and `"-Inf"`, which its output schema allows, and `prodserver.mcp.call` returns them as `Inf` and `-Inf`. An argument can't carry them: `build` requires `encoding="Invertible"` for an example call that passes one, and `prodserver.mcp.call` refuses an argument to a JSON tool that holds one, with `prodserver:mcp:IncompatibleArgumentType`. In a cell, a `duration`, a struct field with no schema of its own, or an output that may be text or a number, an output's `Inf` still gives a tool error. `build` stops for an output, or a struct field, that is text in one example call and `Inf` in another. See [NaN, Inf and One-Element Outputs](./docs/concepts/schemas.md#nan-inf-and-one-element-outputs).
* **An endpoint with no archive behind it raises `prodserver:mcp:UnknownArchive`, after one wait of about a minute.** Production Server answers 404 alike for an archive it doesn't have and one it is still deploying, so `list`, `call`, `read` and `exist` resend the request every 2 seconds, 30 times by default (`list` and `exist` resent 10 times, `read` 3). The waiting used to happen twice: the `HttpError` it ended with also set off the retry for a stale protocol revision, so a missing archive took about 50 seconds for `list` and two minutes for `call`. The error says that the two can't be told apart, and to try again if this was the first request to a newly deployed archive. `list` no longer raises `prodserver:mcp:UnknownServer`. A 404 that the framework sends, with a body, isn't resent. When the wait begins, the function warns that it is waiting and why (`prodserver:mcp:WaitingForArchive`), and the warning and the error name any archives with similar names that the server lists. `metrics` checks an endpoint's archive the same way: it used to raise `UnknownArchive` at once, which was wrong while an archive deployed, and it resends a refused connection once, not 30 times (a minute or two, for a server that isn't running). `list` and `exist` wait 60 seconds for each reply, as `call` and `read` do, not 30. See [An Archive That Answers 404](./docs/reference/call.md#an-archive-that-answers-404).
* **A `file:` URL that names another host is refused**, with `prodserver:mcp:BadFilePath`. `file://server/share/x.mat` used to read the server's own `/share/x.mat`, ignoring the host. The host may be empty or `localhost`. A share on another machine is still a UNC path, `file:////server/share/x.mat`. See [URL Scheme](./docs/concepts/wrapper-functions.md#url-scheme).
* **A `datetime` of `Inf` or `-Inf` is refused** with `prodserver:mcp:IncompatibleArgumentType`, as an argument or an output, in either wire encoding. ISO 8601 has no form for it: it used to be sent as the text `0InfInf`, which plain JSON's date-time schema rejects, and the invertible encoding read back as text.
* **Plain JSON's NaN arrives as NaN.** A scalar NaN was sent as `null`, which `jsondecode` reads as an empty array, so a NaN argument reached the tool as `[]`, or was rejected by a `(1,1) double` parameter, and a NaN output came back as `[]`. `prodserver.mcp.call` now sends a NaN argument, or struct field, as `[null]`, which reads back as NaN. A tool's output sends it as `null`, which its output schema allows, and `prodserver.mcp.call` reads that back as NaN. NaN in an array was, and is, sent as `null`. An empty output or struct field whose schema describes one value, such as one whose example calls all returned a scalar, now gives a tool error, as it would arrive as NaN.
* **A plain JSON tool's outputs match its `outputSchema`,** for a client that checks `structuredContent` against it, as the MCP specification recommends. A `double` or `single` output's schema is `{"type": ["number", "null", "string"], "pattern": "^-?Inf$"}`, for NaN and `Inf`. An output that may be an array is always sent as one, even with one element: `[5]`, not `5`. A matrix doesn't match: plain JSON sends it as an array of its rows, which its schema doesn't describe. See [NaN, Inf and One-Element Outputs](./docs/concepts/schemas.md#nan-inf-and-one-element-outputs).
* **`deploy` raises `prodserver:mcp:DeployedArchiveUnresponsive` when verification gets no answer.** A ping that was refused while the server started a worker used to end verification with `matlab.net.http`'s own error; it is now pinged again. A ping that times out ends verification at once, as it has already waited the whole `timeout`. See [`deploy`](./docs/reference/deploy.md).
* **`metrics` raises `prodserver:mcp:ServerUnresponsive` when `/api/metrics` times out**, as it does for a refused connection. It used to raise MATLAB's own error, which showed the address as given. A timeout isn't resent. Any other failure, such as an HTTP status, still raises MATLAB's error, without the address's user information. See [`metrics`](./docs/reference/metrics.md).
* **`exist` returns `true` for a tool or resource the server lists more than once.** It used to return `false`. `call` and `read` still refuse it as not unique.
* **`prodserver.mcp.call` returns a plain JSON tool's array of strings as a `string` array.** It used to return a cell of char, or, for one element, a char. A vector comes back as a column, as numbers do. Code that tests the result with `iscell` or passes it to `cellfun` needs changing; `s{k}` still gives the k-th string as a char. See [Outputs](./docs/reference/call.md#outputs).
* **The server checks a `%#schema`'s `pattern` as ECMAScript reads it, and `build` rejects more keyword values.** `\d`, `\w` and `\b` match ASCII digits and word characters only, `\x41B` is `AB`, `\<` is `<`, and `\uHHHH` and `\cX` are accepted. An inline flag such as `(?i)`, or a possessive quantifier such as `a++`, which ECMAScript doesn't have, stops `build` with `InvalidParameterSchema`, because a client that compiles the pattern rejects the tool's schema. A `{` that starts no quantifier, as in `a{`, is the character. So does a letter escape ECMAScript doesn't define, such as `\a`. A length, count or bound that isn't a number, such as `"maxLength": null`, also stops `build`: every call to the tool used to fail. `enum`, `const` and `uniqueItems` compare values as JSON does, so `65` is no longer `"A"`, and `1` is no longer `true`. In a list of types such as `["array", "string"]`, a single value is checked as one value first, so `maxLength` limits a string. See [Checked Constraints](./docs/reference/schema-format.md#checked-constraints).

Other changes:
* A server built with `app` serves the view as a `ui://` resource, links it to the tools in `_meta.ui.resourceUri`, and advertises the `io.modelcontextprotocol/ui` extension. Its `uri2json` tool, which the view uses to read data, sends numbers as a plain JSON output does, `Inf` as text included, and always as an array. It is offered only to clients that declare MCP Apps support, and is marked app-only for their hosts. Other clients, including `prodserver.mcp.call` and `list`, don't see it in `tools/list`, and are refused if they call it. `/signature` describes it only to a `2025-06-18` session whose client declared MCP Apps support. See [Security](./docs/concepts/security.md#mcp-apps-and-uri2json).
* `build` reserves the tool names `uri2json` and `read_mcp_resource`, the framework's own, and raises `prodserver:mcp:ReservedToolName` for a tool or function given either. See [`build`](./docs/reference/build.md).
* On a server with an app, `tools/list` under `2026-07-28` carries `cacheScope: private` and `ttlMs: 0`, because it depends on the client.
* New metrics `MCP_uri2json_Refused` and `MCP_uri2json_Refused_<revision>` count `uri2json` calls refused to clients without MCP Apps support, on a server with an app. See [Server Metrics](./docs/guides/server-metrics.md).
* The server writes its own lines to the MPS log, `[mcp:<level>] <id> ...`, at or above the instance's `--log-severity`. Each names the request's JSON-RPC `id`, archive and tool, and its W3C `traceparent`, from the HTTP header or `_meta`, if it sent one. Text a client sent is quoted with its control, line-separator and bidirectional characters, and its backticks, escaped, so it can't break a line or end the quote. See [Server Log](./docs/guides/server-metrics.md#server-log).
* The STDIO bridge, `mcpstdio2http.py`, starts a new session and retries the request when the server answers 404 to a `2025-06-18` session. See [STDIO Bridge](./docs/guides/client-configuration.md#stdio-bridge).
* The Periodic Noise example's `cleanSignal` names its second input `frequency`, not `period`, and accepts only frequencies between 1 and 499 Hz, which its schema now states.

# 1.6: Oct. 2026
Servers support two MCP revisions: `2025-06-18`, which uses sessions, and `2026-07-28`, which is stateless and adds `server/discover`. Each request is served by the revision it is written for. Under `2026-07-28`, list results carry `ttlMs` and `cacheScope` cache hints. See [Protocol Conformance](./docs/concepts/protocol-conformance.md) and, for the cache hints, [Security](./docs/concepts/security.md#cached-list-results).

Changes from 1.5.0 behavior:
* **`MCP-Protocol-Version`, if sent, may be `2025-06-18` or `2026-07-28`**, or `2025-03-26` or `2024-11-05`, which are served as `2025-06-18`. Once the server has [attributed the request to a revision](./docs/concepts/protocol-conformance.md#how-a-request-gets-a-revision), any other value gets HTTP 400 with error `-32022`, which lists the supported versions. A request it can't attribute, with neither `_meta` nor a session, gets `-32602` first, whatever the header says. `2026-07-28` requests must send the header, and it must match the version in the request's `_meta`.
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
