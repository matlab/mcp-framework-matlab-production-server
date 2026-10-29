# prodserver.mcp.ping
```MATLAB
tf = ping(endpoint)
```
Determine whether the MCP tool at `endpoint` is active and accepting requests. `ping` sends `GET /<archive>/ping`, the framework's own liveness check, not the MCP `ping` method, so it works under either protocol revision. The function returns true if the tool is available and false otherwise. Once its arguments are valid it doesn't throw: any failure to reach the tool returns false. An `endpoint` that isn't a URI at all raises `prodserver:mcp:BadURI`.
  
### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of the MCP server | "http://localhost:9910/primeSequence/mcp" |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| tf | logical | Whether the MCP tool is available | true |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds to pause between retries | 2 |
| retry | integer | Number of times to retry after a refused connection, a timeout or HTTP 404 (an archive still being unpacked). Any other failure returns false at once. A dead endpoint takes about `retry*delay` seconds to report false. | 30 |
| timeout | integer | Number of seconds to wait for each reply | 60 |

# Examples

Determine whether the tool `primeSequence` is available at `http://localhost:9910/primeSequence/mcp`.
```MATLAB
tf = prodserver.mcp.ping("http://localhost:9910/primeSequence/mcp")
```
The return value `tf` is a scalar logical true or false.
***

Return false for a badly formed MCP tool URL.
```MATLAB
tf = prodserver.mcp.ping("WWW://localhost:9910/primeSequence/mcp")
```
The return value `tf` is false, since WWW:// is an invalid MCP tool URL prefix.

--- Copyright 2025-2026 The MathWorks, Inc. ---
