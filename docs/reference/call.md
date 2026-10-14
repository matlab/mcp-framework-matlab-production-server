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
| tool | string | Name of the MCP tool to invoke | "primeSequenceMCP" |
| varargin | comma-separated list | Input arguments | 9, "Gaussian" |
| varargout | comma-separated list | Output arguments | x,y,z |

### Outputs

Outputs are positional. `call` returns them in this order:

1. The names in the tool's output schema `required` list, in schema order.
2. Any further output names in the tool's signature, in signature order.

You can ask for fewer outputs than the tool returns. `call` drops the rest. It can't do otherwise: MATLAB discards outputs beyond `nargout`, as it does for any function.

Asking for more outputs than the tool declares raises `prodserver:mcp:TooFewOutputs`.

A call with no output arguments, written as a statement, returns the first output in `ans`.

### Errors

| Identifier | Raised when |
| :--- | :--- |
| `prodserver:mcp:NonUniqueTool` | The server has no tool named `tool`, or more than one |
| `prodserver:mcp:NoInputSchema` | The tool's description has no input schema |
| `prodserver:mcp:TooManyInputs` | `varargin` has more arguments than the tool's input schema allows |
| `prodserver:mcp:TooFewInputs` | `varargin` has fewer arguments than the tool's input schema requires |
| `prodserver:mcp:MissingSignature` | The server returned no signature for the tool |
| `prodserver:mcp:MissingRequiredArguments` | `varargin` has fewer arguments than the tool has required inputs |
| `prodserver:mcp:UnevenOptionalArguments` | The name/value arguments after the positional ones don't form pairs |
| `prodserver:mcp:NoStructuredContent` | The tool declares required outputs, but the response has no `structuredContent` |
| `prodserver:mcp:TooFewOutputs` | You asked for more outputs than the tool declares, or for any output from a tool that declares none |
| `prodserver:mcp:MissingOutputs` | The response lacks an output the tool declares |

Errors from the server arrive as one of three identifiers:

| Identifier | Raised when |
| :--- | :--- |
| `prodserver:mcp:ToolError` | The tool ran and raised an error. The message includes the tool's error text. |
| `prodserver:mcp:RemoteError` | The server rejected the request with a JSON-RPC error. The message includes the server's text and error code. |
| `prodserver:mcp:HttpError` | The server answered with an HTTP error status and no JSON-RPC error |

See [Protocol Conformance](../concepts/protocol-conformance.md#json-rpc-error-codes) for what each JSON-RPC error code means.

`call` opens an MCP session to reach the tool and closes it however the call ends, including when it raises. If closing fails, `call` issues the warning `prodserver:mcp:TerminateFailed` and still returns the tool's outputs.

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

***

Invoke the `detectEdge` tool with two required and two optional inputs.
```MATLAB
image = "file:/image/data/circuit.jpg";
edges = "file:/image/data/circuit_edges.jpg";
prodserver.mcp.call("http://localhost:9910/edges/mcp","detectEdge",image,edges,...
          algorithm="Canny", aperture=7)
```
--- Copyright 2025-2026 The MathWorks, Inc. ---
