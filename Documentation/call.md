# prodserver.mcp.call
```MATLAB
[varargout] = call(endpoint, tool, varargin)
```
Call the named `tool` hosted by the Model Context Protocol server at `endpoint` with
all the input arguments in `varargin`. Output arguments returned in `varargout`. Inputs may be required or optional. Required arguments are positional (order matters) while optional arguments are order-independent; all required arguments must appear in varargin before any optional arguments.

Either or both of `varargin` and `varargout` may be empty. 

### Required Inputs and Available Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |
| tool | string | Name of the MCP tool to invoke | "primeSequenceMCP" |
| varargin | comma-separated list | Input arguments | 9, "Gaussian" |
| varargout | comma-separated list | Output arguments | x,y,z |

### Examples

Invoke `cleanSignal` tool with three required inputs:
```MATLAB
noisy = "file:/input/data/noisySignal.csv";
clean = "file:/output/data/cleanSignal.csv";
frequency = 60;
prodserver.mcp.call("http://localhost:9910/signal/mcp", "cleanSignal", noisy, frequency, clean)
```

***

Invoke the `detectEdge` tool with two required and two optional inputs:
```MATLAB
image = "file:/image/data/circuit.jpg";
edges = "file:/image/data/circuit_edges.jpg";
prodserver.mcp.call("http://localhost:9910/edges/mcp","detectEdge",image,edges,...
          algorithm="Canny", aperture=7)
```
