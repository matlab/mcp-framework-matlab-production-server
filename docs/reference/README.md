# Reference

Function signatures, options, and return values for the `prodserver.mcp` namespace.

## Functions

Call each function with its full namespace prefix, for example `prodserver.mcp.build`.

| Function | Description | Example |
| :--- | :--- | :--- |
| [agent.setup](./agent-setup.md) | Install MCP Framework skills for AI coding agents | `agent.setup` |
| [build](./build.md) | Package function as MCP tool | `build("principalStress", example=@() principalStress([1 2 3], "max"))` |
| [call](./call.md) | Invoke a deployed tool (for testing) | `call(endpoint, "principalStress", [1 2 3], "max")` |
| [deploy](./deploy.md) | Upload archive to MATLAB Production Server | `deploy(ctf, "localhost", 9910)` |
| [exist](./exist.md) | Check existence of a tool on the server | `exist(endpoint, "principalStressMCP", "tool")` |
| [list](./list.md) | List MCP primitives at an endpoint | `list(endpoint, "Tools")` |
| [metrics](./metrics.md) | Retrieve server metrics catalog | `metrics(endpoint)` |
| [ping](./ping.md) | Check if a server is responsive | `ping(endpoint)` |
| [read](./read.md) | Read an MCP resource by URI | `read(endpoint, "mcp://materials/aluminum_6061")` |
| [schema](./schema.md) | Generate tool descriptions by observing calls | `schema("myFunc", @() myFunc(1,2))` |

## Utilities

| Name | Description |
| :--- | :--- |
| [mcpstdio2http.py](./mcpstdio2http.md) | MCP STDIO-to-HTTP bridge for clients that require STDIO transport |
| [linePlot.py](./lineplot.md) | MCP STDIO server that creates line plots from CSV files |

## Schema Format

The [schema format reference](./schema-format.md) documents the JSON Schema structure that `build` and `schema` produce.

--- Copyright 2026 The MathWorks, Inc. ---
