# MCP Framework for MATLAB Production Server

Publish MATLAB&reg; functions as [Model Context Protocol](https://modelcontextprotocol.io/) tools on [MATLAB Production Server&trade;](https://www.mathworks.com/products/matlab-production-server.html). AI agents call your functions, gaining domain-specific expertise in engineering, science, and data analysis.

## Prerequisites

- [MATLAB](https://www.mathworks.com/products/matlab.html) R2025b or later
- [MATLAB Compiler SDK&trade;](https://www.mathworks.com/products/matlab-compiler-sdk.html)
- [MATLAB Production Server](https://www.mathworks.com/products/matlab-production-server.html) R2022a or later
- An [MCP client](https://modelcontextprotocol.io/clients) (Claude Desktop, Claude Code, VS Code with Copilot, or any HTTP-capable client)

## Install

In MATLAB, open the **Add-On Explorer** (Home tab → Add-Ons) and search for "MCP Framework for MATLAB Production Server." Select **Install**.

If you use an AI coding agent, register the build skill so the agent can build and deploy tools on your behalf:

```MATLAB
prodserver.mcp.agent.setup
```

## Quick Start

```MATLAB
% Build an MCP tool — the framework runs your example to determine parameter types
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");

% Verify deployment
prodserver.mcp.ping("http://localhost:9910/principalStress/mcp")

% Call the tool directly
prodserver.mcp.call("http://localhost:9910/principalStress/mcp", ...
    "principalStress", [120 -50 80], "maxShear")
```

Your function is now available to any MCP client connected to that server. See the [Getting Started](./docs/getting-started.md) guide for a complete walkthrough.

## Key Features

- **[Building MCP tools](./docs/guides/building-tools.md)** — The framework packages your functions and deploys them to MPS. Supports [single functions](./Examples/Primes/Primes.md), [multi-tool servers](./Examples/MultiTool/MultipleTools.md), [large data](./Examples/Periodic%20Noise/PeriodicNoise.md), and [structured inputs](./Examples/StructuredData/StructuredData.md).
- **[MCP Resources](./docs/guides/resources.md)** — Serve read-only reference data (material properties, calibration tables) alongside your tools, so the LLM uses real values instead of guessing. [Materials example](./Examples/Materials/Materials.md)
- **[Server metrics](./docs/guides/server-metrics.md)** — Monitor deployed tools with built-in counters at framework, server, and tool level.
- **[AI agent skills](./docs/guides/agent-skills.md)** — Let Claude Code build and deploy tools on your behalf from natural language.
- **[Discovery](./docs/concepts/discovery.md)** — Deployed tools register with the MPS discovery endpoint so clients can find them automatically.

**Documentation:** [Getting Started](./docs/getting-started.md) | [Guides](./docs/guides/) | [Concepts](./docs/concepts/) | [Reference](./docs/reference/)

## License

See [license.txt](./license.txt).

## Contact

<https://www.mathworks.com/support/contact_us.html>

--- Copyright 2025-2026 The MathWorks, Inc. ---
