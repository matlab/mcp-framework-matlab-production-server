# Discovery

When you deploy an MCP tool to MATLAB Production Server, the framework registers it with the MPS [discovery endpoint](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html). Clients can query this endpoint to find available tools without knowing their exact URLs.

## The Two-Step Discovery Process

Finding the tools deployed on an MPS instance requires two HTTP requests:

1. **`GET /api/discovery`** — returns the names of all deployed archives
2. **`GET /<archive>/signature`** — returns the tool signatures for a specific archive

### Step 1: Find the Archives

```
GET http://localhost:9910/api/discovery
```

The response lists every deployed archive on the instance. Each archive entry includes a `functions` field showing the MCP handler entry point:

```json
{
  "discoverySchemaVersion": "1.0.0",
  "archives": {
    "analysisTools": {
      "archiveSchemaVersion": "1.2.0",
      "archiveUuid": "analysisTools_5338a235-078d-4d43-9b66-b27ee2feeb64",
      "functions": {
        "prodserver.mcp.internal.mcpHandler": {
          "signatures": [
            {
              "help": "Model Context Protocol entry point enabling AI agents to invoke MCP tools. MCP-Versions: 2025-06-18, 2026-07-28",
              "inputs": [
                {"name": "request", "mwtype": "struct", "mwsize": [],
                 "help": "MCP JSON-RPC request"}
              ],
              "outputs": [
                {"name": "response", "mwtype": "struct", "mwsize": [],
                 "help": "MCP JSON-RPC response"}
              ]
            }
          ]
        }
      },
      "matlabRuntimeRelease": "R2026b",
      "matlabRuntimeVersion": "26.2.0"
    }
  }
}
```

The archive name (`analysisTools`) is the key you need for step 2. An archive hosts an MCP server if its functions include `prodserver.mcp.internal.mcpHandler`. The `help` text ends with `MCP-Versions:` followed by the MCP revisions the server supports.

From R2027a, discovery is on for every archive, so an archive built with `discovery=false` is listed too. Its entry has a stand-in for each exported function, `mcpHandler` among them, with argument names but empty help, types and sizes. Only an archive built with `discovery=true` has the `MCP-Versions:` help text. Up to R2026b, an archive built with `discovery=false` isn't listed.

### Step 2: Get the Tool Signatures

Use the archive name from step 1 to query the `/signature` endpoint:

```
GET http://localhost:9910/analysisTools/signature
```

This returns the MATLAB-level signatures of every tool in the archive — parameter names, types, sizes, and whether each is required or optional. This example is abridged: each `input` and `output` also has `group` and `default` members, which give each parameter's name-value group and default value.

```json
{
  "principalStress": {
    "function": "principalStress",
    "encoding": "JSON",
    "input": {
      "name": ["stressState", "component"],
      "type": ["double", "string"],
      "kind": ["Required", "Required"],
      "order": ["stressState", "component"],
      "validation": [
        {"size": "(1,3)", "type": "double", "fcn": []},
        {"size": "(1,1)", "type": "string", "fcn": []}
      ]
    },
    "output": {
      "name": "sigma",
      "type": "double",
      "kind": "Optional",
      "order": "sigma",
      "validation": [
        {"size": "(1,1)", "type": "double", "fcn": []}
      ]
    }
  }
}
```

For multi-tool archives, the response contains one entry per tool. The signatures contain MATLAB types, not JSON types. A parameter's `type` is its declared class; otherwise the class the `example` calls passed, with the classes joined by `|` if they passed different ones, such as `"uint16|double"`; otherwise `""`, meaning unknown. `validation` and `default` come from the arguments block, so they're the same whether or not the tool was built with `example`.

Every archive also has an entry for `read_mcp_resource`, left out of the example above. It's the framework's built-in tool for [reading resources](../guides/resources.md), and `build` adds it to every server, even one with no resources, so it appears in `/signature` and in `tools/list` alongside your own tools.

An archive built with an MCP App also has `uri2json`, the tool its view reads data with. `/signature` lists it only for a request that carries a `2025-06-18` `Mcp-Session-Id` whose `initialize` declared MCP Apps support (`io.modelcontextprotocol/ui`). A request without one, such as any `2026-07-28` client's, doesn't see it. See [Security](./security.md#mcp-apps-and-uri2json).

A tool with no inputs may have no `input` member at all, and a tool with no outputs can have no `output` member. Whether the member is absent or empty depends on how the tool was built, so treat the two the same.

## Automatic Registration

Discovery is enabled by default. Every call to `build` embeds discovery metadata in the archive:

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

After deployment, the archive appears in the `/api/discovery` response and its tools are queryable via `/signature`. No additional configuration is needed.

To keep an archive's description out of the discovery endpoint, pass `discovery=false`:

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    discovery=false, ...
    server="http://localhost:9910");
```

The tool still works normally: it answers MCP requests at its endpoint. Up to R2026b, the archive doesn't appear in `/api/discovery` responses. From R2027a, it's listed with stand-in entries instead, as [Step 1](#step-1-find-the-archives) describes.

## Querying from MATLAB

Use `prodserver.mcp.list` to query the list of MCP tools from within MATLAB. `prodserver.mcp.list` does not use the `/api/discovery` endpoint. It sends an MCP `tools/list` request to the server instead:

```MATLAB
tools = prodserver.mcp.list("http://localhost:9910/analysisTools/mcp", "Tool")
```
The `/api/discovery` endpoint is meant for clients that cannot call `tools/list`.

## Discovery and `server/discover`

`server/discover` is an MCP method, not part of MPS discovery. Despite the similar name, it answers a different question:

| | `/api/discovery` | `server/discover` |
| :--- | :--- | :--- |
| Defined by | MATLAB Production Server | MCP revision `2026-07-28` |
| Scope | Every archive on the instance | One archive, at `/<archive>/mcp` |
| Request | `GET`, no MCP | A JSON-RPC `POST` |
| Returns | Archive names, and `MCP-Versions:` in the `help` text | The supported revisions, the server's capabilities and its instructions. Not the tools — use `tools/list`. |
| Affected by `discovery=false` | Yes. Up to R2026b, the archive is left out. From R2027a, it's listed with stand-in entries. | No |

Use `/api/discovery` to find which archives host MCP servers. Use `server/discover` to find out how to talk to one of them. See [Protocol Conformance](./protocol-conformance.md#methods).

## Configuration Requirements

Discovery must be enabled on the MPS instance by adding `--enable-discovery` to `main_config`. If disabled, `/api/discovery` returns an empty response. The `/signature` endpoint operates independently and requires no additional configuration.

## See Also

- [Building MCP Tools](../guides/building-tools.md) — deploying tools to MPS
- [`build` reference](../reference/build.md) — the `discovery` option
- [`list` reference](../reference/list.md) — the `Tool` option
- [MPS Discovery API](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html) — MathWorks documentation

--- Copyright 2026 The MathWorks, Inc. ---
