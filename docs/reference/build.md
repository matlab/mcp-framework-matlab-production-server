# `prodserver.mcp.build`
```MATLAB
[ctf,endpoint] = build(fcn, opts)
```
Create an MCP tool from `fcn` by packaging it into a CTF archive deployable to MATLAB Production Server. Optionally upload the archive to an active MATLAB Production Server instance.

MCP Framework creates HTTP-based MCP servers that use Streamable HTTP in JSON-only mode: each request gets a single JSON response, and the server never opens a server-sent events (SSE) stream. See [Protocol Conformance](../concepts/protocol-conformance.md). MCP servers hosted by MATLAB Production Server can use [HTTPS, OAuth2, and OIDC](https://www.mathworks.com/help/mps/security.html) for security.

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
| endpoint | string | Network endpoint of MCP server. Requires `server` optional input. | "http://localhost:9910/primeSequence/mcp" |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `wrapper="None"`.
| Argument | Type | Description | Default | Example |
| :---     | :--- | :---        | :---    |:---     |
| archive | string | Base name of deployable archive. | Base name of the first `fcn`. | "primeMCP" |
| definition | string or struct | Complete and correct MCP tool definition: the path to a JSON file, or a structure with both `tools` and `signatures` fields. JSON text is not accepted. | `string.empty` (generate one) | "primeMCP.json" |
| discovery | logical | Include discovery metadata in the archive for the MPS [/api/discovery](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html) endpoint. | true | false |
| encoding | WireEncoding | [Wire encoding](../concepts/wire-encoding.md) of tool arguments and results: `"JSON"` or `"Invertible"`. A scalar applies to every tool; a vector gives one encoding per function in `fcn`, or `build` raises `prodserver:mcp:SizeMismatch`. | "JSON" | "Invertible" |
| example | function_handle, string, or cell | Exercise functions for schema generation. Calls [`schema()`](./schema.md) internally to generate definitions. Incompatible with `definition`. | [] | @() myFunc(1,"test") |
| files | string vector | Full path(s) to one or more files to add to the deployable archive. Every tool in the archive can read them. | `string.empty` | "/sandbox/data/weather/anomaly.mat" |
| folder | string | Full or relative path to folder in which to write the deployable archive. Created if it doesn't exist. | "./deploy" | "/sandbox/work/mcp/archives" |
| import | struct | ImportOptions for tool arguments, one field per argument. Used by generated wrappers. | `struct.empty` | delimitedTextImportOptions |
| maxLiteralSize | double | Largest number of elements an argument can have and still be passed by value. A generated wrapper passes larger arguments by reference, through file URLs. Applies to the sizes declared in argument blocks. | 64 | 1000 |
| resource | struct | [MCP Resources](../guides/resources.md) to include on the server. Structure(s) with at least `uri` and `contents` fields. | [] | See [Resources](../guides/resources.md) |
| retry | integer | Not used. The upload uses the defaults of [`deploy`](./deploy.md). | 2 | 0 |
| routes | enumeration | Where the routes file goes: embedded in the archive (`"Archive"`), as instance-global routes (`"Instance"`), or for a MATLAB-hosted test server (`"DevAndTest"`). | "Archive" | "Instance" |
| server | string | Network address of active MATLAB Production Server. If given, `build` uploads the archive with [`deploy`](./deploy.md). | `string.empty` (don't upload) | "http<!-- -->://localhost:9910" |
| stop | BuildStage | Last build stage to run: `"Wrapper"`, `"Definition"`, `"Routes"`, `"Archive"` or `"Deploy"`. Outputs of later stages are `""`. Useful for inspecting generated wrappers and definitions without compiling. | "Deploy" | "Definition" |
| timeout | integer | Not used. The upload uses the defaults of [`deploy`](./deploy.md). | 30 | 17 |
| tool | string | Name by which the tool is known on the server. One per function in `fcn`. | Base name of `fcn`. | "primeMCP" |
| typemap | struct | MATLAB type names (field names) mapped to JSON type names (values), applied to every generated description. Has no effect on a supplied `definition`. | [] | struct('uint64','integer') |
| wrapper | string | [Data marshaling wrapper](../concepts/wrapper-functions.md) for each function in `fcn`: the path to a wrapper file, `"Auto"` to generate one only when needed, `"None"` to skip, or `""` to always generate one. Give one entry per function, or one keyword for all of them. With `example`, only `"Auto"` or `"None"` is allowed, and no wrapper is built. | "Auto" | "primeMCP.m" |

`example` and `definition` are mutually exclusive. If `example` is provided, `build()` generates definitions by observing function calls via [`prodserver.mcp.schema`](./schema.md). See [Schemas](../concepts/schemas.md) for background on schema generation approaches.

# Examples

Build the MATLAB function `primeSequence` into the MCP tool `primeSequence`. Do not use or generate a data marshaling wrapper function. Automatically upload the tool to the MATLAB Production Server instance at `http://localhost:9910`. The MATLAB Production Server instance must be running or the upload fails.
```MATLAB
[ctf,endpoint] = prodserver.mcp.build("primeSequence",wrapper="None",server="http://localhost:9910");
```

***

Build the MATLAB function `plotTrajectories` into the MCP tool `plotTrajectories`. Automatically generate a data marshaling wrapper function. Set the output folder to "/work/mcp/tools". Do not upload the generated tool to any MATLAB Production Server instance.
```MATLAB
ctf = prodserver.mcp.build("plotTrajectories", folder="/work/mcp/tools");
```

***

Build the MATLAB function `starChart` into an MCP tool of the same name. Automatically generate a wrapper function. Specify import options for the `ngc` and `constellation` parameters.

```MATLAB
importer.ngc = delimitedTextImportOptions(DataLines=1,ImportErrorRule='error');
importer.constellation = delimitedTextImportOptions(ImportErrorRule='omitrow');
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
