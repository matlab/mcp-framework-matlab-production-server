# `prodserver.mcp.build`
```MATLAB
[ctf,endpoint] = build(fcn, opts)
```
Create an MCP tool from fcn by packaging fcn into a CTF archive deployable to MATLAB 
Production Server. Optionally upload the archive to an active instance of MATLAB 
Production Server.

MCP Framework creates pure HTTP-based MCP servers. These MCP servers do not support
streamable HTTP or HTTP with server-side events (HTTP SSE). MCP Servers hosted by MATLAB
Production Server may use [HTTPS, OAuth2 and OIDC](https://www.mathworks.com/help/mps/security.html) for security.

MATLAB Production Server exposes the `/mcp` endpoint via [custom web handlers](https://www.mathworks.com/help/mps/server/use-web-handler-for-custom-routes-and-custom-payloads.html).

Note that there is no conflict or collision between the MCP endpoint names (for example, `/mcp`) and the names of the MCP tools and the MATLAB functions that implement them. You may for example create an MCP tool named `mcp` from a MATLAB function named `mcp` in the file `mcp.m`.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| fcn | string | Name of the function to package as an MCP tool | "primeSequence" |
### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    
| ctf | string | Full path to generated CTF archive. | "/sandbox/work/deploy/primeSequence.ctf" |
| endpoint | string | Network endpoint of MCP server. Requires `server` optional input. | "http://localhost/primeSequence/mcp" |

### Optional Inputs (Name/Value pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=17`.
| Argument | Type | Description | Default | Example | 
| :---     | :--- | :---        | :---    |:---     |
| archive | string | Base name of deployable archive. | Base name of fcn. | "primeMCP" | 
| definition | string, struct or file | Complete and correct MCP tool definition. | Empty struct | "primeMCP.json" |
| folder | string | Full or relative path to folder in which to write deployable archive. | "./deploy" | "/sandbox/work/mcp/archives" |
| import | struct | ImportOptions for tool arguments | [] | delimitedTextImportOptions |
| retry | integer | Number of times to retry network operations that have timed out. Total attempts will be retry + 1. | 2 | 0 |
| routes | enumeration | Embed routes(in archive or use global routes? | "Archive" | "Global" | 
| server | string | Network address of active MATLAB Production Server | "" | "http<!-- -->://localhost:9910" | 
| timeout | integer | Timeout, in seconds, for server interactions. | 30 | 17 |
| tool | string | Name by which the tool will be known on the server. | Base name of `fcn`. | "primeMCP" | 
| wrapper | string | Path to [data marshaling wrapper](./ExternalData.md) function | "" | "primeMCP.m" |

`fcn`, `wrapper` and `definition`

# Examples

Build the MATLAB function `primeSequence` into the MCP tool `primeSequence`. Do not use or 
generate a data marshaling wrapper function. Automatically upload the tool to the MATLAB 
Production Server instance at `http://localhost:9910`. The MATLAB Production Server instance 
must be running or the upload will fail.
```MATLAB
[ctf,endpoint] = prodserver.mcp.build("primeSequence",wrapper="None",server="http://localhost:9910");
```

***

Build the MATLAB function `plotTrajectories` into the MCP tool `plotTrajectories`. Automatically
generate a data marshaling wrapper function. Set the output folder to "/work/mcp/tools". Do not
upload the generated tool to any MATLAB Production Server.
```MATLAB
ctf = prodserver.mcp.build("plotTrajectories", folder="/work/mcp/tools");
```

***

Build the MATLAB function `starChart` into an MCP tool of the same name. Automatically generate a wrapper function. Specify import options for the `ngc` and `constellation` parameters. 

```MATLAB
importer.ngc = delimtedTextImportOptions(DataLines=1,ImportErrorRule='error');
importer.constellation = delimitedTextImportOptions(ImportErrorRule='omit');
ctf = prodserver.mcp.build("starChart",import=importer);
```

***

Build a single server containing four tools to produce fractal images: `twinDragon`, `dragonDraw`, `snowflake` and `turtleGraphic`. Note the tools have different names than the MATLAB functions that implement them.

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