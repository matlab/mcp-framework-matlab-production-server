# MCP Framework for MATLAB Production Server
Publish your MATLAB&reg; functions to [MATLAB Production Server&trade;](https://www.mathworks.com/products/matlab-production-server.html)
as [Model Context Protocol (MCP)](https://modelcontextprotocol.io/docs/getting-started/intro) tools. This allows AI agents to 
call your functions, enhancing their capabilities with domain-specific expertise.

# Required Products
In addition to this repo, you'll need:
* [MATLAB](https://www.mathworks.com/products/matlab.html) R2025b or later.
* [MATLAB Compiler SDK&trade;](https://www.mathworks.com/products/matlab-compiler-sdk.html) compatible with your MATLAB version.
* Access to [MATLAB Production Server](https://www.mathworks.com/products/matlab-production-server.html) R2022a or later.
* An [MCP client](https://modelcontextprotocol.io/clients) that does not require streamable HTTP. MCP servers created with this repo do not support streamable HTTP or HTTP Server Sent Events (SSE).

# Quickstart
To make a MATLAB function available to an LLM as an MCP tool you:
* Install this repo where MATLAB can find it -- and add the top level folder to MATLAB's path.
* Build an MCP tool from a MATLAB function
* Configure your MCP client to make the tool available to your LLM.

## Step 1: Install
Using this add-on requires MATLAB R2025b or later.

Install this add-on to MATLAB with the Add-On Explorer:

1. In MATLAB, go to the **Home** tab, and in the **Environment** section, click the **Add-Ons** icon.
2. In the Add-On Explorer, search for "MCP Framework for MATLAB Production Server".
3. Select **Install**.

## Step 2: Build An MCP Tool 
To create an MCP tool from one of your MATLAB functions:
1. Package the function into a deployable archive.
2. Upload the archive to an active instance of MATLAB Production Server.
3. Verify the upload / installation was successful.

For example, to create an MCP tool from the `primeSequence` function use these commands in MATLAB:

```MATLAB
>> ctf = prodserver.mcp.build("primeSequence",wrapper="None");

>> endpoint = prodserver.mcp.deploy(ctf,"localhost",9910);

>> available = prodserver.mcp.ping(endpoint)
available = 
    true

>> gp = prodserver.mcp.call(endpoint, "primeSequence", 11, "gaussian")
gp = 1×11
     3    7    11    19    23    31    43    47    59    67    71
```

And then you might be able to use it from your LLM host with the prompt: "Generate the first 11 Gaussian primes." 
See the discussion of [external](./Documentation/ExternalData.md) data sources for details of the `wrapper` input to `prodserver.mcp.build`.

## Step 3: Configure MCP Client 
There are many MCP clients and each has its own configuration mechanism for MCP tools. But they all share the 
same idea: identifying the location of each MCP tool and the communication protocol the tool understands. MCP Framework creates HTTP-based MCP tools. To aid development and testing, an STDIO to HTTP server bridge is also included.

This repo has been tested against these MCP clients, using the configuration each of these links describes.
* [LLMs with MATLAB](./Examples/MATLABOpenAI/MATLABOpenAI.md) with OpenAI LLMs
* [Claude&reg; Desktop](./Documentation/ConfigureClaude.md)
* [Microsoft&reg; VS Code with GitHub&reg; Copilot](./Documentation/ConfigureVSCode.md)

Any client that supports pure HTTP-based MCP servers should work. Note that MCP Framework for MATLAB Production Server does not support streamable HTTP -- connections are transient and transactional, not persistent.

# Examples
The Examples folder contains several complete MCP tools of varying complexity. Each example includes a MATLAB Live Script (*.mlx file) that demonstrates how to create, deploy and test the MCP tool.

* [Primes](./Examples/Primes/Primes.md): Generates four different kinds of prime number sequences. Does not require a data marshaling wrapper function.
* [Periodic Noise](./Examples/Periodic%20Noise/PeriodicNoise.md): Eliminates periodic noise from a measured signal. Demonstrates explicit use of an automatically generated wrapper function.
* [Earthquake](./Examples/Earthquake/Earthquake.md): Generates plots of earthquake data. Demonstates use of a user-written wrapper function.

To become effective MCP tools, MATLAB functions must accommodate the MCP environment. In particular,
your functions must: 
* Provide an LLM (and human!) readable [description](./Documentation/DescribingFunctions.md) of their purpose and capabilities.
* Process large or complex data via [external sources and sinks](./Documentation/ExternalData.md).

If you add comments and function argument blocks to your code, MCP Framework can automate most
of this process. See the links for details.

# Reference

## Public Functions
The functions have their own namespace, `prodserver.mcp`, which must be used as a prefix when 
calling them in MATLAB. For example, call `build` using its full name: `prodserver.mcp.build`.
| Function | Description | Example | 
| :---     | :---        | :---    |
| [build](./Documentation/build.md) | Package function as MCP tool | `build("primeSequence",wrapper="None")` |
| [call](./Documentation/call.md) | Invoke deployed tool (for testing) | `call(endpoint, "primeSequence", 9, "Eisenstein")` |
| [deploy](./Documentation/deploy.md) | Upload tool to MATLAB Production Server | `deploy(tool, "localhost", 9910)` |
| [exist](./Documentation/exist.md) | Check existence of tool on MATLAB Production Server | `exist("http://localhost:9910/primes/mcp", "primeSequenceMCP", "tool")` |
| [list](./Documentation/list.md) | List MCP primitives available at `endpoint` | `list(endpoint, "Tools")` |
| [ping](./Documentation/ping.md) | Send a ping to server at `endpoint`. Return true if server responsive. | `ping(endpoint)` |

## Utilities
| Name | Description |  
| :---     | :---    |
| [mcpstdio2http.py](./Documentation/mcpstdio2http.md) | MCP STDIO to HTTP server bridge. |
| [linePlot.py](./Documentation/linePlot.md) | MCP STDIO server. Creates line plots from CSV files. |

In addition, each MCP server supports a simple `ping` HTTP endpoint which confirms server existence and readiness.
Once the `primeSequence` tool is uploaded to a MATLAB Production Server running at `http://localhost:9910`, send a ping with `curl`:
```sh
% curl http://localhost:9910/primeSequence/ping
pong
```

## Security
Security is your responsiblity. MCP Servers hosted by MATLAB Production Server may use 
[HTTPS, OAuth2 and OIDC](https://www.mathworks.com/help/mps/security.html) for security.
Set security parameters by configuration in MATLAB Production Server. 

## Directory Structure
| Folder | Description |
| :---   | :---        | 
| +prodserver | Top-level directory for prodserver.mcp namespace. Contains the bulk of the repo functions. |
| Documentation | Collection of Markdown reference pages documenting the public functions. |
| Examples | Complete examples of MCP tools and the workflows to create, deploy and use them. |
| Test | Unit and Integration tests. |
| Utilities | Mostly standalone functions and scripts that make the repo easier to integrate with other environments. |

# License
The license is available in the [license.txt](./license.txt) file in this GitHub repository.