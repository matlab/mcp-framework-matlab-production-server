# `prodserver.mcp.deploy`
```MATLAB
endpoint = deploy(archive,host,port,opts)
```
Upload a Model Context Protocol-enabled CTF archive to an active MATLAB Production Server instance. Uses the MATLAB Production Server [RESTful API](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-deployable-archive-upload.html). Before using this function, configure MATLAB Production Server to allow archive management via `--enable-archive-management` in the instance `main_config` file.

### Inputs 
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| archive | string | Base name of the generated archive. | "primeSequence" |
| host | string | Name of the network host running MATLAB Production Server. | "mps.mathworks.com" |
| port | uint16 | Port number on host. | 9910 |
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
| retry | integer | Number of times to retry HTTP requests. | 10 | 17 |
| timeout | integer | Number of seconds to wait for HTTP requests. | 180 | 60 |
| verify | integer | Number of times to retry upload verification. Zero turns off verification. | 5 | 3 |
| delay | integer | Number of seconds to pause between retries. | 2 | 5 |

If `verify` is non-zero, `deploy` sends a `ping` to the uploaded archive to verify that upload and installation succeeded. A newly uploaded archive is typically recognized by MATLAB Production Server very quickly. Expect verification to take a few seconds.

### Upload Failures

`deploy` checks the server's answer to the upload before it starts verifying. If the server rejected the upload, `deploy` raises at once rather than pinging for an archive that will never appear. The error message includes the server's explanation when there is one.

| Identifier | Server response | Retried? |
| :--- | :--- | :--- |
| `prodserver:mcp:ArchiveUploadNoResponse` | None. Every attempt timed out. | Yes, up to `retry` times |
| `prodserver:mcp:ArchiveUploadRejected` | HTTP 4xx | No. The same request gets the same answer. |
| `prodserver:mcp:ArchiveUploadFailed` | HTTP 5xx | Yes, up to `retry` times, `delay` seconds apart |

A 5xx is a server-side failure and may be transient. Check the server log, then call `deploy` again.

Before it uploads anything, `deploy` can raise:

| Identifier | Raised when |
| :--- | :--- |
| `prodserver:mcp:ServerUnresponsive`, `prodserver:mcp:InactiveServer` | The server didn't answer its health check |
| `prodserver:mcp:ArchiveMustBeCTF` | `archive` doesn't have a `.ctf` extension |
| `prodserver:mcp:ArchiveManagementDisabled` | The server doesn't have `--enable-archive-management` set |
| `prodserver:mcp:ArchiveOverwriteDisabled` | An archive with the same name is installed and `overwrite` is `false` |

After a successful upload, verification can raise:

| Identifier | Raised when |
| :--- | :--- |
| `prodserver:mcp:DeployedArchiveUnresponsive` | The archive didn't answer `ping` within the `verify` and `retry` budget |
| `prodserver:mcp:NeedMultiMCOSMode` | The server failed to load the archive. The message names the environment variable to set before restarting the server. See [Several Archives on One Server](#several-archives-on-one-server). |

### Several Archives on One Server

Every MCP archive carries its own copy of the framework's classes. A MATLAB Production Server worker that hosts more than one MCP archive can load one archive's copy of a class, then fail to load another archive's tool definitions. The cure is to run the server in multi-MCOS mode, which gives each archive its own copy of the classes: set the environment variable `MW_MULTIMCOS_MODE` to `true` on the server machine, then restart the server.

`deploy` can't always catch the problem. Verification uses `ping`, which doesn't load the tool definitions, so `deploy` can succeed and a later request fail. Depending on where it appears, the failure looks like this:

| Where | What you see |
| :--- | :--- |
| `deploy` | `prodserver:mcp:NeedMultiMCOSMode` |
| `prodserver.mcp.call` | `prodserver:mcp:RemoteError`, with code `-32603` |
| Any other MCP client, on `tools/list`, `tools/call`, `resources/list` or `resources/read` | HTTP 500 with JSON-RPC error `-32603` |

In the last two cases, the error message says that another archive in the same worker may have loaded a different copy of a framework class, and names `MW_MULTIMCOS_MODE`. If the tool definitions fail to load for any other reason, the message names the archive and the definition file and gives the reason instead. The server doesn't remember the failure; it tries to load the definitions again on the next request.

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
