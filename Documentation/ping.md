# prodserver.mcp.ping
```MATLAB
tf = ping(endpoint)
```
Determine if the MCP tool at `endpoint` is active and accepting requests. Returns true if the tool is available and false otherwise. Never throws an exception; returns false if any error occurs.
  
### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| tf | logical | Is the MCP Tool available? | true |

### Optional Inputs (Name/Value pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds pause between retries | 3 |
| retry | integer | Number of times to retry on HTTP protocol errors (404, for example) | 2 | 
| timeout | integer | Number of seconds to wait for a reply | 60 |

# Examples

Determine if the tool `primeSequence` is available at the network address `http://localhost:9910/primeSequence/mcp`:
```MATLAB
tf = ping("http://localhost:9910/primeSequence/mcp")
```
The return value `tf` will be a scalar logical true or false.
***

Return false for badly formed MCP tool URL:
```MATLAB
tf = exist("WWW://localhost:9910/primeSequence/mcp")
```
The return value `tf` will be false, since WWW:// is an invalid MCP tool URL prefix.

