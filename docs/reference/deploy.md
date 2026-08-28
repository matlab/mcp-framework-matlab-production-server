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
| https | logical | Use HTTPS. Uses HTTP if false. | false | true | 
| overwrite | logical | Overwrite existing archives. | true | true | 
| retry | integer | Number of times to retry HTTP requests. | 2 | 17 |
| timeout | integer | Number of seconds to wait for HTTP requests. | 180 | 60 |
| token | string | JSON Web Token for authorization. | None | N/A | 
| verify | integer | Number of times to retry upload verification. Zero turns off verification. | 5 | 3 |

If `verify` is non-zero, `deploy` sends a `ping` to the uploaded archive to verify that upload and installation succeeded. A newly uploaded archive is typically recognized by MATLAB Production Server very quickly. Expect verification to take a few seconds.

# Examples

Upload `primeSequence.ctf` to a MATLAB Production Server instance running at `localhost:9910` using HTTPS.

```MATLAB
endpoint = prodserver.mcp.deploy("/work/deploy/primeSequence.ctf","localhost",9910,https=true);
```
***

Upload `primeSequence.ctf` without verifying the upload.

```MATLAB
endpoint = prodserver.mcp.deploy("/work/deploy/primeSequence.ctf","localhost",9910,verify=0);
```
--- Copyright 2025-2026 The MathWorks, Inc. ---
