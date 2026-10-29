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
| protocol | string | MCP revision: `"discover"` asks the server, `"2025-06-18"` or `"2026-07-28"` uses that one. See [Protocol Revision](#protocol-revision). | `"discover"` |
| retry | integer | Number of times to resend a request that gets HTTP 404, 408 or 429. A refused connection or a timeout isn't retried. | 10 |
| timeout | integer | Number of seconds to wait for each reply. | 30 |

Fields of the tool structure:

| Field | Type | Description | 
| :---  | :--- | :---        |
| name  | string | Name of the tool. |
| description | string | Human-readable and AI-readable description of the tool. |
| inputSchema | struct | Type and description of each input parameter. |
| outputSchema | struct | Type and description of each output parameter. |
| server | struct | MCP server structure. |

The `properties` field of each schema is a structure with one field per parameter. Each parameter field value captures the `type` and `description` of the parameter.

The server field describes the server hosting the tool and provides enough information for MCP hosts to call the tool.

**HTTP server structure**
| Field | Type | Description | 
| :---  | :--- | :---        |
| type  | string | Type of the server. Always 'http'. |
| url | string | Network address of the MCP server hosting the tool. |

### Protocol Revision

With the default `protocol="discover"`, the function picks the revision as [`call`](./call.md#protocol-revision) does: it probes with `server/discover`, falls back to `2025-06-18`, and remembers the answer for each endpoint. If the request fails with `prodserver:mcp:RemoteError`, `prodserver:mcp:HttpError`, `prodserver:mcp:UnattributableRequest`, `prodserver:mcp:NoSessionFromServer` or `prodserver:mcp:MethodNotFound`, it forgets the answer, probes again and retries once.

Naming a revision skips the probe and the retry. The function also remembers that revision for the endpoint, so later calls that use `"discover"`, including `call`, use it too. Any value other than the three above raises `prodserver:mcp:UnsupportedProtocolVersion`. That includes the aliases `2025-03-26` and `2024-11-05`, which the server accepts but the client doesn't.

An `endpoint` with no archive behind it raises `prodserver:mcp:HttpError` with status 404 when the revision is `2025-06-18`, which is what `"discover"` picks for it. With `protocol="2026-07-28"` it raises `prodserver:mcp:UnknownServer`.

# Examples

List the tools available on the server running at `http://localhost:9910/primeSequence/mcp`.
```MATLAB
tools = prodserver.mcp.list("http://localhost:9910/primeSequence/mcp","tool")
```
The return value `tools` is a cell array with one structure per tool. Each structure has the fields `name`, `description`, `inputSchema`, `outputSchema`, and `server`.

`inputSchema` and `outputSchema` are optional. If they do not appear, the tool has none of the corresponding parameters.

***
Input schema of the `cleanSignal` tool. The auto-generated wrapper externalizes the large `noisy` input and `clean` output as file URLs:

```
inputSchema
    properties
        noisyURL
                   type: 'string'
            description: 'URL pointing to the input value for 'noisy'. The content of the URL is:
                          Noisy signal'
               examples: {3×1 cell}
        period
                   type: 'number'
            description: 'period'
        cleanURL
                   type: 'string'
            description: 'URL pointing to the output value for 'clean'. This value never returned
                          inline. Read result from URL using scheme-appropriate method: file
                          system read for file: URLs, HTTP GET for http:// URLs and so on. The
                          content of the URL is:
                          Filtered signal'
               examples: {3×1 cell}
              writeOnly: 1
```
Each `examples` cell holds sample URLs such as `'file:///tmp/storage/data.csv'`. `cleanURL` is `writeOnly`: the tool writes its output there. Since the only output became an input, `outputSchema` has no properties.

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
