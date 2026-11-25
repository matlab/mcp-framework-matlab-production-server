# Getting Started

Build your first MCP tool from a MATLAB function, deploy it to MATLAB Production Server, and call it from an AI agent. This takes about five minutes once you have the prerequisites in place.

## Prerequisites

- [MATLAB](https://www.mathworks.com/products/matlab.html) R2025b or later
- [MATLAB Compiler&trade;](https://www.mathworks.com/products/compiler.html), which MATLAB Compiler SDK requires
- [MATLAB Compiler SDK&trade;](https://www.mathworks.com/products/matlab-compiler-sdk.html)
- [MATLAB Production Server](https://www.mathworks.com/products/matlab-production-server.html) R2025b or later. Archives built in R2025b need the R2025b MATLAB Runtime, and a server can host runtimes from its own release or earlier.
- An [MCP client](https://modelcontextprotocol.io/clients) (Claude Desktop, Claude Code, VS Code with Copilot, or any HTTP-capable client)

## Write a Function

You can create an MCP tool from any MATLAB function. This example uses `principalStress`, which computes principal stresses from a 2D stress state using Mohr's circle.

```MATLAB
function sigma = principalStress(stressState, component)
% Compute principal stresses using Mohr's circle. 
% 
%    sigma = principalStress(stressState, component) computes the principal
%        stress component ("min", "max", "maxShear") in MPa from the 2D 
%        stressState [tension, compression, shear].

    sx = stressState(1);     % X normal force (sigma x)
    sy = stressState(2);     % Y normal force (sigma y)
    txy = stressState(3);    % Shear stress   (tau xy)

    R = sqrt(((sx - sy) / 2)^2 + txy^2);

    switch component
        case "max"
            sigma = (sx + sy) / 2 + R;   % Maximum principal stress
        case "min"
            sigma = (sx + sy) / 2 - R;   % Minimum principal stress
        case "maxShear"
            sigma = R;                   % Max. in-plane shear stress
    end
end
```
Save it as `principalStress.m` in your current folder, or anywhere on the MATLAB path. Or `cd` to the framework's `Examples/PrincipalStress` folder, which has a copy.

To use `principalStress`, an LLM needs a *tool description* that specifies what the function does and how to call it. The framework [determines input types](./guides/building-tools.md#how-tool-descriptions-work) by examining any argument blocks and watching your function run in MATLAB.

## Set Up a Server

The steps below deploy to a MATLAB Production Server instance at `localhost:9910`. If you don't have one, create it with the command-line tools in the `script` folder of your MATLAB Production Server installation:

```
mps-setup                      # once per installation: say where the MATLAB Runtime is
mps-new ~/mps/mcp -v           # create an instance in ~/mps/mcp
```

Then, in the instance's `config/main_config`, turn on the features the framework uses. Each line may already be there, commented out with `#`; remove the `#`, or add the line.

```
--enable-archive-management    # lets prodserver.mcp.deploy upload archives
--enable-discovery             # for /api/discovery
--enable-metrics               # for prodserver.mcp.metrics
```

A new instance listens on port 9910 (`--http 9910`). Start it, and check that it's running:

```
mps-start -C ~/mps/mcp
curl http://localhost:9910/api/health     # {"status":"ok"}
```

This page needs only archive management: without it, `deploy` can't upload. [Discovery](./concepts/discovery.md) and [metrics](./guides/server-metrics.md) need their own options.

## Build

`prodserver.mcp.build` packages your function into a deployable archive containing an MCP server. Pass `build` an example call so the framework can determine the types of the inputs and outputs.

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));
```

The framework runs your example and observes that `stressState` is a 3-element numeric vector and `component` is a string. Combining the types with the comments from your source code produces the [tool description](./concepts/describing-functions.md) for the LLM. `build` then compiles the function with MATLAB Compiler SDK and produces a deployable archive.

## Deploy

Upload the archive to a running MATLAB Production Server instance.

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "http://localhost:9910");
```

`deploy` returns the endpoint URL where your tool is now listening: `http://localhost:9910/principalStress/mcp`.

Give `deploy` the server's address as a URL, with its scheme and port. For a shared server that uses HTTPS, for example:

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "https://mps.example.com:9920");
```

`deploy` also takes the host and port separately, as `deploy(ctf, "localhost", 9910)`, with `scheme="https"` for HTTPS. See [deploy](./reference/deploy.md).

To build and deploy in one step, pass `build` the `server` option.

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

## Verify

Confirm the tool is live.

```MATLAB
prodserver.mcp.ping(endpoint)
```
```
ans =
  logical
   1
```

List the server's tools to see what an MCP client will see:

```MATLAB
tools = prodserver.mcp.list(endpoint, "Tool");
cellfun(@(t) string(t.name), tools)
```
```
ans =
  2×1 string array
    "principalStress"
    "read_mcp_resource"
```

`read_mcp_resource` is the framework's built-in tool for [reading resources](./guides/resources.md). `build` adds it to every server, even one with no resources, because some clients can't read resources any other way.

To find the maximum principal stress for a state of 120 MPa tension, 50 MPa compression, and 80 MPa shear, test with a direct call.

```MATLAB
sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "max")
```
```
sigma =
  151.7262
```

## Connect an MCP Client

Your tool is an HTTP-based MCP server. Connect any MCP client that supports HTTP transport. For example, to connect Claude Code, add this to the MCP configuration.

```json
{
  "mcpServers": {
    "principalStress": {
      "url": "http://localhost:9910/principalStress/mcp",
      "type": "http"
    }
  }
}
```

For details on configuring other clients, see the [client configuration guide](./guides/client-configuration.md).

## Try a Prompt

With the client configured, try this prompt:

> A point in a steel beam is under 120 MPa normal stress in X, 50 MPa compressive stress in Y, and 80 MPa shear. What are the principal stresses and maximum shear stress? Will it yield if the steel has a 250 MPa yield strength?

The LLM reads the tool description, calls `principalStress` multiple times with different `component` values, and interprets the results. It compares the stresses to yield strength and reports whether the design is safe.

---

## Next Steps

| Goal | Read |
|------|------|
| Handle large array or structured data | [Functions with Large Data](./guides/building-tools.md#functions-with-large-data) |
| Provide reference data alongside tools | [MCP Resources](./guides/resources.md) |
| Give a tool an interactive view in the chat | [MCP Apps](./guides/mcp-apps.md) |
| Bundle multiple tools on one server | [Multi-Tool Servers](./guides/building-tools.md#multi-tool-servers) |
| Monitor deployed tools | [Server Metrics](./guides/server-metrics.md) |
| Let Claude Code build tools for you | [AI Agent Skills](./guides/agent-skills.md) |
| Understand schema generation in depth | [Describing Functions](./concepts/describing-functions.md) |

--- Copyright 2026 The MathWorks, Inc. ---
