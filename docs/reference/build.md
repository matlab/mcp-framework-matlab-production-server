# `prodserver.mcp.build`
```MATLAB
[ctf,endpoint] = build(fcn, opts)
```
Create an MCP tool from `fcn` by packaging it into a CTF archive deployable to MATLAB Production Server. Optionally upload the archive to an active MATLAB Production Server instance.

MCP Framework creates pure HTTP-based MCP servers. These MCP servers do not support streamable HTTP or HTTP with server-side events (HTTP SSE). MCP servers hosted by MATLAB Production Server can use [HTTPS, OAuth2, and OIDC](https://www.mathworks.com/help/mps/security.html) for security.

MATLAB Production Server exposes the `/mcp` endpoint via [custom web handlers](https://www.mathworks.com/help/mps/server/use-web-handler-for-custom-routes-and-custom-payloads.html).

There is no conflict between MCP endpoint names (for example, `/mcp`) and the names of MCP tools or the MATLAB functions that implement them. You can create an MCP tool named `mcp` from a MATLAB function named `mcp` in the file `mcp.m`.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| fcn | string | Name of the function to package as an MCP tool | "primeSequence" |
### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    
| ctf | string | Full path to generated CTF archive. | "/sandbox/work/deploy/primeSequence.ctf" |
| endpoint | string | Network endpoint of MCP server. Requires `server` optional input. | "http://localhost/primeSequence/mcp" |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default | Example | 
| :---     | :--- | :---        | :---    |:---     |
| archive | string | Base name of deployable archive. | Base name of fcn. | "primeMCP" | 
| definition | string, struct, or file | Complete and correct MCP tool definition. | Empty struct | "primeMCP.json" |
| example | function_handle, string, or cell | Exercise functions for schema generation. Calls [`schema()`](./schema.md) internally to generate definitions. Incompatible with `definition`. | [] | @() myFunc(1,"test") |
| files | string vector | Full path(s) to one or more files to add to the deployable archive. | "" | "/sandbox/data/weather/anomaly.mat" |
| folder | string | Full or relative path to folder in which to write the deployable archive. | "./deploy" | "/sandbox/work/mcp/archives" |
| import | struct | ImportOptions for tool arguments. | [] | delimitedTextImportOptions |
| resource | struct | [MCP Resources](../guides/resources.md) to include on the server. Structure(s) with at least `uri` and `contents` fields. | [] | See [Resources](../guides/resources.md) |
| retry | integer | Number of times to retry network operations that have timed out. Total attempts equal retry + 1. | 2 | 0 |
| routes | enumeration | Embed routes in archive or use global routes. | "Archive" | "Global" | 
| server | string | Network address of active MATLAB Production Server. | "" | "http<!-- -->://localhost:9910" | 
| discovery | logical | Include discovery metadata in the archive for the MPS [/api/discovery](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html) endpoint. | true | false |
| timeout | integer | Timeout, in seconds, for server interactions. | 30 | 17 |
| tool | string | Name by which the tool is known on the server. | Base name of `fcn`. | "primeMCP" | 
| wrapper | string | Path to [data marshaling wrapper](../concepts/wrapper-functions.md) function, or "None" to skip, or "Auto" to generate only when needed. | "Auto" | "primeMCP.m" |

`example` and `definition` are mutually exclusive. If `example` is provided, `build()` generates definitions by observing function calls via [`prodserver.mcp.schema`](./schema.md). See [Schemas](../concepts/schemas.md) for background on schema generation approaches.

# Examples

Build the MATLAB function `primeSequence` into the MCP tool `primeSequence`. Do not use or generate a data marshaling wrapper function. Automatically upload the tool to the MATLAB Production Server instance at `http://localhost:9910`. The MATLAB Production Server instance must be running or the upload fails.
```MATLAB
[ctf,endpoint] = prodserver.mcp.build("primeSequence",wrapper="None",server="http://localhost:9910");
```

***

Build the MATLAB function `plotTrajectories` into the MCP tool `plotTrajectories`. Automatically generate a data marshaling wrapper function. Set the output folder to "/work/mcp/tools". Do not upload the generated tool to any MATLAB Production Server.
```MATLAB
ctf = prodserver.mcp.build("plotTrajectories", folder="/work/mcp/tools");
```

***

Build the MATLAB function `starChart` into an MCP tool of the same name. Automatically generate a wrapper function. Specify import options for the `ngc` and `constellation` parameters.

```MATLAB
importer.ngc = delimitedTextImportOptions(DataLines=1,ImportErrorRule='error');
importer.constellation = delimitedTextImportOptions(ImportErrorRule='omit');
ctf = prodserver.mcp.build("starChart",import=importer);
```

***

Build a single server containing four tools to produce fractal images: `twinDragon`, `dragonDraw`, `snowflake`, and `turtleGraphic`. The tools have different names than the MATLAB functions that implement them.

The build function automatically generates tool definitions and wrapper functions as necessary.

```MATLAB
% Tool names -- the names used to call the tool. These are the names
% reported by prodserver.mcp.list.
tool = ["twinDragon",  "snowflake", "dragonDraw", "turtleGraphic"];

% Functions that implement the tools. Each of these names must be a
% function on MATLAB's path.
fcn = ["chaosdragon", "snowflake", "renderDragon", "drawvector"];

% Specify a server name -- otherwise the server would have the same
% name as the first tool in the tool list.
server = "Fractals";
ctf = prodserver.mcp.build(fcn, tool=tool, archive=server, folder="./deploy")
```

***

Build `schemaCompute` using example-based schema generation. The example exercises the function with representative inputs so that MCP Framework observes argument types at runtime.
```MATLAB
ctf = prodserver.mcp.build("schemaCompute", ...
    example=@() schemaCompute(1.0, 2.0, 3.0, scale=2.0, label="test"), ...
    server="http://localhost:9910");
```

--- Copyright 2025-2026 The MathWorks, Inc. ---
