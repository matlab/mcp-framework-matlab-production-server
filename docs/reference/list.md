# `prodserver.mcp.list`
```MATLAB
items = list(endpoint,type)
```
List the tools or resources on the given Model Context Protocol server. `type` must always be a single string. The output `items` is a cell array of MATLAB structures corresponding to the MCP JSON definitions of the available MCP primitives of `type`. Each element in `items` describes a single primitive.

Tools and resources are two of the *primitives* potentially hosted by a Model Context Protocol server. Tools have a name and description. Resources have a URI and optional name. Some primitives have other properties.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |
| type | string | Type of MCP primitive | "tool" or "resource" |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| items | cell | Cell array of structs, one per primitive. Structure fields vary by `type`. | See tool and resource structure tables below. |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds to pause between retries. | 2 |
| retry | integer | Number of times to retry on HTTP protocol errors (404, for example). | 10 | 
| timeout | integer | Number of seconds to wait for a reply. | 30 |


Fields of the tool structure:

| Field | Type | Description | 
| :---  | :--- | :---        |
| name  | string | Name of the tool. |
| description | string | Human-readable and AI-readable description of the tool. |
| inputSchema | struct | Type and description of each input parameter. |
| outputSchema | struct | Type and description of each output parameter. |
| server | struct | MCP server structure. |

The `properties` field of each schema is a structure with one field per parameter. Each parameter field value captures the `type` and `description` of the parameter.

The server field describes the server hosting the tool and provides enough information for MCP hosts to call the tool. Two types of servers exist: http and stdio.

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

List the tools available on the server running at `http://localhost:9910/primeSequence/mcp`.
```MATLAB
tools = list("http://localhost:9910/primeSequence/mcp","tool")
```
The return value `tools` is a structure with fields `name`, `description`, `inputSchema`, `outputSchema`, and `server`.

`inputSchema` and `outputSchema` are optional. If they do not appear, the tool has none of the corresponding parameters.

***
Input schema of the `cleanSignal` tool. The auto-generated wrapper externalizes the large `noisy` input and `clean` output as file URLs:

```
inputSchema
    properties
        noisyURL
                   type: 'string'
            description: 'URL pointing to the input value for noisy.'
        period
                  type: 'number'
            description: 'period'
        cleanURL
                 type: 'string'
            description: 'URL pointing to the output value for clean.'
```
`outputSchema` has an analogous structure.

***
Fields of the resource structure:

| Field | Type | Description |
| :---  | :--- | :---        |
| uri | string | Unique identifier for the resource. Pass this to `read` and `exist`. |
| name | string | Machine-readable name. May be absent. |
| title | string | Human-readable display title. May be absent. |
| description | string | Describes the resource content. May be absent. |
| mimeType | string | MIME type of the content. |
| server | struct | MCP server structure (same as tools). |

***
List resources and read one by URI:
```MATLAB
resources = prodserver.mcp.list("http://localhost:9910/myServer/mcp", "Resource")
result = prodserver.mcp.read(endpoint, resources{1}.uri);
```

--- Copyright 2025-2026 The MathWorks, Inc. ---
