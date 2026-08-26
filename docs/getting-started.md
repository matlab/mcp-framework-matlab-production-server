# Getting Started

Build your first MCP tool from a MATLAB function, deploy it to MATLAB Production Server, and call it from an AI agent. This takes about five minutes once you have the prerequisites in place.

*Prerequisites: MATLAB R2025b+, MATLAB Compiler SDK, a running instance of MATLAB Production Server (R2022a+), and an MCP client such as Claude Desktop or VS Code with Copilot.*

---

## Write a Function

Any MATLAB function can become an MCP tool. Here's `principalStress` — it computes principal stresses from a 2D stress state using Mohr's circle:

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
To use `principalStress`, an LLM needs a *tool description* — what the function does and how to call it. The framework [determines input types](./guides/building-tools.md#how-tool-descriptions-work) by examining any argument blocks and watching your function run in MATLAB.

## Build

`prodserver.mcp.build` packages your function into a deployable archive containing an MCP server. Pass `build` an example of how to call your function so the framework can determine the types of the inputs and outputs.

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));
```

The framework runs your example and observes that `stressState` is a 3-element numeric vector and `component` is a string. Combining the types with the comments from your source code produces the [tool description](./concepts/describing-functions.md) for the LLM. `build` then compiles the function with MATLAB Compiler SDK, and produces a deployable archive.

## Deploy

Upload the archive to a running MATLAB Production Server instance:

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

`deploy` returns the endpoint URL where your tool is now listening: `http://localhost:9910/principalStress/mcp`.

Build and deploy in one step by passing `build` the `server` option:

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

## Verify

Confirm the tool is live:

```MATLAB
prodserver.mcp.ping(endpoint)
```
```
ans =
    true
```

Test it with a direct call — find the maximum principal stress for a state of 120 MPa tension, 50 MPa compression, and 80 MPa shear:

```MATLAB
sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "max")
```
```
sigma =
  151.7262
```

## Connect an MCP Client

Your tool is an HTTP-based MCP server. Connect any MCP client that supports HTTP transport. 
For example, to connect Claude Code, add this to the MCP configuration:

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

See the [client configuration guide](./guides/client-configuration.md) for details on configuring other clients.

## Try a Prompt

With your client configured, try:

> A point in a steel beam is under 120 MPa normal stress in X, 50 MPa compressive stress in Y, and 80 MPa shear. What are the principal stresses and maximum shear stress? Will it yield if the steel has a 250 MPa yield strength?

The LLM reads the tool description, calls `principalStress` multiple times with different `component` values, and interprets the results — comparing to yield strength and reporting whether the design is safe.

---

## Next Steps

You have a working MCP tool. Where to go from here depends on what you need:

| Goal | Read |
|------|------|
| Handle large array or structured data | [Functions with Large Data](./guides/building-tools.md#functions-with-large-data) |
| Provide reference data alongside tools | [MCP Resources](./guides/resources.md) |
| Bundle multiple tools on one server | [Multi-Tool Servers](./guides/building-tools.md#multi-tool-servers) |
| Monitor deployed tools | [Server Metrics](./guides/server-metrics.md) |
| Let Claude Code build tools for you | [AI Agent Skills](./guides/agent-skills.md) |
| Understand schema generation in depth | [Describing Functions](./concepts/describing-functions.md) |

--- Copyright 2026 The MathWorks, Inc. ---
