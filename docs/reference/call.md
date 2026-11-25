# `prodserver.mcp.call`
```MATLAB
[varargout] = call(endpoint, tool, varargin)
```
Call the named `tool` hosted by the Model Context Protocol server at `endpoint` with all the input arguments in `varargin`. The function returns output arguments in `varargout`. Inputs may be required or optional. Required arguments are positional (order matters), while optional arguments are order-independent. All required arguments must appear in `varargin` before any optional arguments.

A tool with no required inputs takes an empty `varargin`.

### Required Inputs and Available Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |
| tool | string | Name of the MCP tool to invoke | "primeSequence" |
| varargin | comma-separated list | Input arguments | 9, "Gaussian" |
| varargout | comma-separated list | Output arguments | x,y,z |

### Outputs

Outputs are positional. `call` returns them in this order:

1. The names in the tool's output schema `required` list, in schema order.
2. Any further output names in the tool's signature, in signature order.

You can ask for fewer outputs than the tool returns. `call` drops the rest. It can't do otherwise: MATLAB discards outputs beyond `nargout`, as it does for any function.

Asking for more outputs than the tool declares raises `prodserver:mcp:TooFewOutputs`.

A call with no output arguments, written as a statement, returns the first output in `ans`.

For a tool built with `encoding="JSON"`, `call` reads each output by its schema. An array of strings comes back as a `string` array, even with one element. A vector of them comes back as a column, as numbers do: plain JSON has no orientation.

### Invalid Arguments

`call` first finds the tool in the server's `tools/list`. If the server doesn't list it, from a typo, or an archive redeployed without that tool, `call` raises `prodserver:mcp:UnknownTool`, and the message lists the tools the server has. If the server lists two tools with that name, it raises `prodserver:mcp:NonUniqueTool`.

Then, before it sends the `tools/call`, `call` checks the listed tool and your inputs:

| Error | Cause |
| :--- | :--- |
| `prodserver:mcp:NoInputSchema` | The listed tool has no `inputSchema`. |
| `prodserver:mcp:TooManyInputs` | More inputs than the schema's `maxProperties`. |
| `prodserver:mcp:TooFewInputs` | Fewer inputs than the schema's `minProperties`, or, without it, than the tool's required inputs. |
| `prodserver:mcp:MissingSignature` | The server's `/signature` route doesn't describe the tool. |

The first and last mean the archive is broken: tell its author.

The server checks the arguments against the tool's input schema before it runs the tool. If they don't fit, the tool doesn't run. Under `2025-06-18`, `call` raises `prodserver:mcp:JsonRpcError` (JSON-RPC error `-32602`). Under `2026-07-28`, it raises `prodserver:mcp:ToolError`, and the tool's error text begins "Input validation error:". The server counts such a call in the `MCP_<tool>_Rejected` metric, not `MCP_<tool>_Call`.

### Protocol Revision

`call` picks the MCP revision for you. It sends `server/discover` first and uses `2026-07-28` if the server answers. Otherwise it falls back to `initialize` and `2025-06-18`. It remembers the answer for each endpoint, so later calls skip the probe. If the server doesn't answer at all, `call` uses `2025-06-18` for this call but doesn't remember it, and probes again next time.

If a call fails in a way that can mean the remembered revision is stale, `call` forgets it, probes again and retries the call once. Those failures are JSON-RPC error `-32020`, `-32022` or `-32601`, and a 4xx status with no JSON-RPC error, other than Production Server's own 404 (see below): no revision changes that answer. `call` never retries after the tool may have run: a tool error, any other JSON-RPC error or a 5xx status is raised at once.

### An Archive That Answers 404

MATLAB Production Server answers 404, with no body, for an archive it doesn't have. It answers the same way, for up to a minute or more, for an archive it is still deploying: after a deploy that didn't come from `prodserver.mcp.deploy` or `build`, which wait for the archive themselves, and while a server starts. A client can't tell the two apart. So `call` resends a request that gets that 404 every 2 seconds, for about a minute. If the archive still hasn't answered, it raises `prodserver:mcp:UnknownArchive`, which says how long it waited. If that was the first request to the archive since it was deployed or the server started, try again: a slow start can take several minutes. Otherwise, check the archive name in the endpoint. `list`, `read` and `exist` wait the same way, for `retry` resends `delay` seconds apart, 30 and 2 by default.

At the first such 404, the function warns, `prodserver:mcp:WaitingForArchive`, that it is waiting and why, and that Ctrl+C stops it. If the server's `/api/discovery` is on, the warning and the error also say what it lists: that the archive is listed, and so probably still starting, or which archives have similar names, in case the endpoint is mistyped. To turn the warning off, use `warning("off", "prodserver:mcp:WaitingForArchive")`.

The framework's own 404s carry a JSON-RPC error, and aren't resent: an unknown session (`-32001`), or a method the revision doesn't have (`-32601`).

Each request waits up to 60 seconds for an answer. After a server starts or restarts, the first request to an archive can take longer while a worker loads it, even once `/api/health` says `ok`. So `call` sends a request again, once, when it gets no answer or can't connect, if the request changes nothing: `server/discover`, `initialize`, `tools/list` and the signature request. It never resends `tools/call`, which may have run. A request that still gets no answer raises `prodserver:mcp:RequestTimeout`, which says the server may still be starting. So a call to a server that accepts connections but never answers fails within about four minutes: two timeouts for the revision probe, two for the first request after it. A call to a server that isn't running fails in a few seconds.

Under `2025-06-18`, `call` opens an MCP session to reach the tool and closes it however the call ends, including when it raises. If closing fails, `call` issues the warning `prodserver:mcp:TerminateFailed` and still returns the tool's outputs. `2026-07-28` has no sessions.

### Examples

Invoke the `fuseSensors` tool, which returns three outputs.
```MATLAB
[fused, weights, uncertainty] = prodserver.mcp.call(endpoint, "fuseSensors", laser, ultrasonic);
```
Ask for fewer to receive the leading outputs only. This call returns `fused` and `weights` and drops `uncertainty`:
```MATLAB
[fused, weights] = prodserver.mcp.call(endpoint, "fuseSensors", laser, ultrasonic);
```

***

Invoke the `cleanSignal` tool with two required inputs and an optional output location.
```MATLAB
noisy = "file:/input/data/noisySignal.csv";
clean = "file:/output/data/cleanSignal.csv";
frequency = 60;
prodserver.mcp.call("http://localhost:9910/cleanSignal/mcp", "cleanSignal", noisy, frequency, cleanURL=clean)
```
The `file:/` form and the `file:///` form (`file:///input/data/noisySignal.csv`, or `file:///C:/data/noisySignal.csv` on Windows) both work. See [URL Scheme](../concepts/wrapper-functions.md#url-scheme).

***

Invoke the `detectEdge` tool with two required and two optional inputs.
```MATLAB
image = "file:/image/data/circuit.jpg";
edges = "file:/image/data/circuit_edges.jpg";
prodserver.mcp.call("http://localhost:9910/edges/mcp","detectEdge",image,edges,...
          algorithm="Canny", aperture=7)
```

--- Copyright 2025-2026 The MathWorks, Inc. ---
