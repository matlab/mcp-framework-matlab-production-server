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
| items | struct | Varies by `type`, formed by encoding JSON description. | Tools structure with fields `name`, `description`, `inputSchema`, `outputSchema` and `server`. |

Fields of the tool structure:

| Field | Type | Description | 
| :---  | :--- | :---        |
| name  | string | The name of the tool. |
| description | string | Human and AI-readable description of the tool. |
| inputSchema | struct | Type and description of each input parameter. |
| outputSchema | struct | Type and description of each output parameter. |
| server | string | MCP server structure. |

The `properties` field of each schema is a structure with one field per parameter. Each parameter's field value captures the `type` and `description` of the parameter. 

The server field describes the server hosting the tool. It provides enough information to allow MCP hosts to call the tool. There are two types of servers: http and stdio.

**HTTP server structure**
| Field | Type | Description | 
| :---  | :--- | :---        |
| type  | string | Type of the server. Always 'http'. |
| url | string | Network address of the MCP server hosting the tool. |

**STDIO server structure**
| Field | Type | Description | 
| :---  | :--- | :---        |
| type  | string | Type of the server. Always 'stdio'. |
| command | string | Command that starts the server. |
| args | array | Strings passed to the command to start the server. |

# Examples

List the tools available on the server running at `http://localhost:9910/primeSequence/mcp`:
```MATLAB
tools = list("http://localhost:9910/primeSequence/mcp","tool")
```
The return value `tools` will be structure with fields `name`, `description`, `inputSchema`, `outputSchema` and `server`. 

`inputSchema` and `outputSchema` are optional. If they do not appear, the tool has none of the corresponding parameters.

***
Input schema of the `cleanSignal` tool, which has three inputs: `noisy`, `frequency` and `clean`. A nested structure:

```
inputSchema
    properties
        noisy
                   type: 'string'
            description: 'The noisy input signal as a file: URL.'
        frequency
                  type: 'number'
            description: 'The frequency or period of the noise to remove.'       
        clean
                 type: 'string'
            description: 'The filtered signal after removing the periodic noise, as a file: URI.'
```
The `outputSchema` has an analogous structure.
