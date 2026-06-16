# prodserver.mcp.exist
```MATLAB
tf = exist(endpoint,name,type)
```
Check for existence of named tools, resources and prompts on the given Model Context Protocol server. `name` may be a list with multiple names, but `type` must always be a single string. The output `tf` is the same size as `name`. Each element in `tf` indicates if the corresponding element of `name` is a known `type` on the server at `endpoint`.

Tools, resouces and prompts are three of the _primitives_ potentially hosted by a Model Context Protocol server. Each primitive has a name and a description.   

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |
| name | string | Name of the MCP primitive | "primeSequenceMCP" |
| type | string | Type of MCP primitive | "tool", "resource" or "prompt" |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| tf | logical | Does the MCP primitive exist? | true |

### Optional Inputs (Name/Value pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds pause between retries | 3 |
| retry | integer | Number of times to retry on HTTP protocol errors (404, for example) | 2 | 
| timeout | integer | Number of seconds to wait for a reply | 60 |

# Examples

Determine if the tool `primeSequenceMCP` exists on the server running at `http://localhost:9910/primeSequence/mcp`:
```MATLAB
tf = exist("http://localhost:9910/primeSequence/mcp","primeSequenceMCP", "tool")
```
The return value `tf` will be a scalar logical true or false.
***

Determine if the tools `toolOne`, `toolTwo` and `toolThree` exist on the server `http://mcp.mathworks.com:8675/mcp`:
```MATLAB
tf = exist("http://localhost:9910/primeSequence/mcp",["toolOne", "toolTwo", "toolThree"], "tool")
```
The return value `tf` will be a three-element vector of logical values. `tf(1)` indicates the existence of `toolOne`, `tf(2)` the existence of `toolTwo` and `tf(3)` the existence of `toolThree`.
