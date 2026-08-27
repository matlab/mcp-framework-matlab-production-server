# prodserver.mcp.ping
```MATLAB
tf = ping(endpoint)
```
Determine whether the MCP tool at `endpoint` is active and accepting requests. The function returns true if the tool is available and false otherwise. It never throws an exception; it returns false if any error occurs.
  
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
| delay | integer | Number of seconds to pause between retries | 3 |
| retry | integer | Number of times to retry on HTTP protocol errors (404, for example) | 2 | 
| timeout | integer | Number of seconds to wait for a reply | 60 |

# Examples

Determine whether the tool `primeSequence` is available at `http://localhost:9910/primeSequence/mcp`.
```MATLAB
tf = ping("http://localhost:9910/primeSequence/mcp")
```
The return value `tf` is a scalar logical true or false.
***

Return false for a badly formed MCP tool URL.
```MATLAB
tf = exist("WWW://localhost:9910/primeSequence/mcp")
```
The return value `tf` is false, since WWW:// is an invalid MCP tool URL prefix.

--- Copyright 2025-2026 The MathWorks, Inc. ---
