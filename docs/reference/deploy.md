# `prodserver.mcp.deploy`
```MATLAB
endpoint = deploy(archive,host,port,opts)
```
Upload a Model Context Protocol-enabled CTF archive to an active MATLAB Production Server instance. Uses the MATLAB Production Server [RESTful API](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-deployable-archive-upload.html). Before using this function, configure MATLAB Production Server to allow archive management via `--enable-archive-management` in the instance `main_config` file.

### Inputs 
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| archive | string | Path to the `.ctf` file to upload. The archive's base name becomes the endpoint's archive segment. | "/work/deploy/primeSequence.ctf" |
| host | string | Name of the network host running MATLAB Production Server, or a full server address such as `"https://mps.mathworks.com:9920"`. Optional; default `"localhost"`. With a full address, don't also give `port` or `scheme`. | "mps.mathworks.com" |
| port | double | Port number on host. Optional; default 9910. | 9910 |
### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| endpoint | string | Network endpoint of MCP server. | "http://localhost:9910/primeSequence/mcp" |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=120`.
| Argument | Type | Description | Default | Example | 
| :---     | :--- | :---        | :---    |:---     |
| scheme | string | URL scheme. | "http" | "https" | 
| overwrite | logical | Overwrite existing archives. | true | true | 
| retry | integer | Number of attempts at each HTTP request, including the first. | 10 | 17 |
| timeout | integer | Number of seconds to wait for the health check, the archive-listing request and the `ping` requests. For the upload itself this is a connect timeout only, since a large archive can take longer to transfer. | 180 | 60 |
| verify | integer | Scales the verification budget: `deploy` sends up to `verify`×`retry` `ping` requests, `delay` seconds apart. Zero turns off verification. | 5 | 3 |
| delay | integer | Number of seconds to pause between retries. | 2 | 5 |

If `verify` is non-zero, `deploy` sends a `ping` to the uploaded archive to verify that upload and installation succeeded. A newly uploaded archive is typically recognized by MATLAB Production Server very quickly. Expect verification to take a few seconds.

Replacing an archive takes longer to show: for several seconds after the upload returns, the server goes on answering with the archive it replaces. So `deploy` waits until the archive answering `ping` is the one it uploaded. The archive names its build in the `MATLAB-MCP-Archive-UUID` header of its `ping` answer: the UUID the compiler gave it, which `deploy` reads from the `.ctf` file. When it has seen that build answer twice, with no answer from the old build in between, `deploy` returns. If the old build is still answering when verification runs out, `deploy` raises `prodserver:mcp:DeployedArchiveStale`. If no `pong` arrives at all, it raises `prodserver:mcp:DeployedArchiveUnresponsive`.

A 404, or an HTTP 500 whose reason phrase or body says "End of file", means the server is still loading the archive, so `deploy` pings again. If `deploy` can't read the UUID from the `.ctf` file, any `pong` counts.

An archive built with an earlier version of the framework doesn't send the header. Then `deploy` asks the server's discovery API (`/api/discovery`, turned on with `--enable-discovery`) which build is installed, waiting at most 10 seconds for the answer. If discovery is off, any `pong` counts, as it always did.

### Upload Failures

`deploy` checks the server's answer to the upload before it starts verifying. If the server rejected the upload, `deploy` raises at once rather than pinging for an archive that will never appear. The error message includes the server's explanation when there is one.

`deploy` retries an upload that gets no answer or an HTTP 5xx status, up to `retry` attempts in all, `delay` seconds apart. It doesn't retry a 4xx status: the same request gets the same answer.

A 5xx is a server-side failure and may be transient. Check the server log, then call `deploy` again.

If the server fails to load the archive after the upload, the error message names the environment variable to set before restarting the server. See [Several Archives on One Server](#several-archives-on-one-server).

### Several Archives on One Server

Every MCP archive carries its own copy of the framework's classes. A MATLAB Production Server worker that hosts more than one MCP archive can load one archive's copy of a class, then fail to load another archive's tool definitions. The cure is to run the server in multi-MCOS mode, which gives each archive its own copy of the classes: set the environment variable `MW_MULTIMCOS_MODE` to `true` on the server machine, then restart the server.

`deploy` can't always catch the problem. Verification uses `ping`, which doesn't load the tool definitions, so `deploy` can succeed and a later request fail. Depending on where it appears, the failure looks like this:

| Where | What you see |
| :--- | :--- |
| `deploy` | `prodserver:mcp:NeedMultiMCOSMode` |
| `prodserver.mcp.call` | `prodserver:mcp:JsonRpcError`, with code `-32603` |
| Any other MCP client, on `tools/list`, `tools/call`, `resources/list` or `resources/read` | HTTP 500 with JSON-RPC error `-32603` |

In the last two cases, the error message reports an internal error loading the archive's tool definitions, says to restart the server in multi-MCOS mode, and names `MW_MULTIMCOS_MODE`. If the tool definitions fail to load for any other reason, the message names the archive and the definition file and gives the reason instead. The server doesn't remember the failure; it tries to load the definitions again on the next request.

# Examples

Upload `primeSequence.ctf` to a MATLAB Production Server instance running at `localhost:9910` using HTTPS.

```MATLAB
endpoint = prodserver.mcp.deploy("/work/deploy/primeSequence.ctf","localhost",9910,scheme="https");
```
***

Upload `primeSequence.ctf` without verifying the upload.

```MATLAB
endpoint = prodserver.mcp.deploy("/work/deploy/primeSequence.ctf","localhost",9910,verify=0);
```
--- Copyright 2025-2026 The MathWorks, Inc. ---
