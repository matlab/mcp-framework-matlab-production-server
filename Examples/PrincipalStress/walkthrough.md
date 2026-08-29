# Principal Stress Analysis

Build your first MCP tool from a MATLAB function, deploy it to MATLAB Production Server, and call it from an AI agent. This walkthrough takes about five minutes.

## The Function

`principalStress` computes principal stresses from a 2D stress state using Mohr's circle. It accepts a three-element stress vector `[sigma_x, sigma_y, tau_xy]` and a component name (`"max"`, `"min"`, or `"maxShear"`).

```MATLAB
function sigma = principalStress(stressState, component)
    sx = stressState(1);
    sy = stressState(2);
    txy = stressState(3);

    R = sqrt(((sx - sy) / 2)^2 + txy^2);

    switch component
        case "max",      sigma = (sx + sy) / 2 + R;
        case "min",      sigma = (sx + sy) / 2 - R;
        case "maxShear", sigma = R;
    end
end
```

Test it locally before building the MCP tool:
```MATLAB
principalStress([120 -50 80], "max")
ans =
  151.7262
```

## Build

Package `principalStress` into a deployable archive. Pass an example call so the framework determines input and output types automatically.

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"));
```

The framework runs your example, observes that `stressState` is a 3-element numeric vector and `component` is a string, and combines that with comments from your source code to produce the MCP tool definition.

## Deploy

Upload the archive to a running MATLAB Production Server instance.

```MATLAB
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);
```

`deploy` returns the MCP endpoint URL: `http://localhost:9910/principalStress/mcp`.

To build and deploy in one step:
```MATLAB
[ctf, endpoint] = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

## Verify

Confirm the tool is live and responding correctly.

```MATLAB
prodserver.mcp.ping(endpoint)
ans =
    true

prodserver.mcp.exist(endpoint, "principalStress", "Tool")
ans =
    true
```

Test the tool end-to-end using the MCP protocol:
```MATLAB
sigma = prodserver.mcp.call(endpoint, "principalStress", [120 -50 80], "max")
sigma =
  151.7262
```

## Connect an MCP Client

The tool is an HTTP-based MCP server. Connect any MCP client that supports HTTP transport. For Claude Code, add this to the MCP configuration:

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

See the [client configuration guide](../../docs/guides/client-configuration.md) for Claude Desktop, VS Code, and other clients.

## Try a Prompt

With the client configured, try this prompt:

> A point in a steel beam is under 120 MPa normal stress in X, 50 MPa compressive stress in Y, and 80 MPa shear. What are the principal stresses and maximum shear stress? Will it yield if the steel has a 250 MPa yield strength?

The LLM reads the tool description, calls `principalStress` three times with different `component` values, and interprets the results. It compares the stresses to yield strength and reports whether the design is safe.

## Next Steps

| Goal | Read |
|------|------|
| Handle large array or structured data | [Building Tools](../../docs/guides/building-tools.md) |
| Provide reference data alongside tools | [MCP Resources](../../docs/guides/resources.md) |
| Bundle multiple tools on one server | [Multi-Tool Servers](../MultiTool/walkthrough.md) |
| Monitor deployed tools | [Server Metrics](../../docs/guides/server-metrics.md) |

--- Copyright 2026 The MathWorks, Inc. ---
