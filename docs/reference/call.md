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

### Invalid Arguments

The server checks the arguments against the tool's input schema before it runs the tool. If they don't fit, the tool doesn't run. Under `2025-06-18`, `call` raises `prodserver:mcp:JsonRpcError` (JSON-RPC error `-32602`). Under `2026-07-28`, it raises `prodserver:mcp:ToolError`, and the tool's error text begins "Input validation error:". The server counts such a call in the `MCP_<tool>_Rejected` metric, not `MCP_<tool>_Call`.

### Protocol Revision

`call` picks the MCP revision for you. It sends `server/discover` first and uses `2026-07-28` if the server answers. Otherwise it falls back to `initialize` and `2025-06-18`. It remembers the answer for each endpoint, so later calls skip the probe.

If a call fails in a way that can mean the remembered revision is stale, `call` forgets it, probes again and retries the call once. Those failures are JSON-RPC error `-32020`, `-32022` or `-32601`, and a 4xx status with no JSON-RPC error. `call` never retries after the tool may have run: a tool error, any other JSON-RPC error or a 5xx status is raised at once.

Production Server answers 404 while an archive is being unpacked, so `call` resends a request that gets 404 for a while first. An endpoint with no archive behind it takes about two minutes to raise an error.

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
period = 60;
prodserver.mcp.call("http://localhost:9910/cleanSignal/mcp", "cleanSignal", noisy, period, cleanURL=clean)
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
