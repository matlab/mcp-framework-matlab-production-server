# prodserver.mcp.list
```MATLAB
items = list(endpoint,type)
```
List the tools, resources or prompts on the given Model Context Protocol server. `type` must always be a single string. The output `items` is a MATLAB structure corresponding to the MCP JSON defintion of the available MCP primitives of `type`. Each element in `items` describes a single primitive.

Tools, resouces and prompts are three of the _primitives_ potentially hosted by a Model Context Protocol server. Each primitive has a name and a description. Some primitives may have other properties.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |
| type | string | Type of MCP primitive | "tool", "resource" or "prompt" |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| items | struct | Varies by `type`, formed by encoding JSON description. | Tools structure with fields `name`, `description`, `inputSchema`, `outputSchema` |

# Examples

List the tools available on the server running at `http://localhost:9910/primeSequence/mcp`:
```MATLAB
tools = list("http://localhost:9910/primeSequence/mcp","tool")
```
The return value `tools` will be structure with fields `name`, `description`, `inputSchema` and `outputSchema`.

