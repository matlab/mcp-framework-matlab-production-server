# Discovery

When you deploy an MCP tool to MATLAB Production Server, the framework registers it with the MPS [discovery endpoint](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html). Clients can query this endpoint to find available tools without knowing their exact URLs.

## The Two-Step Discovery Process

Finding the tools deployed on an MPS instance requires two HTTP requests:

1. **`GET /api/discovery`** — returns the names of all deployed archives
2. **`GET /<archive>/signature`** — returns the tool signatures for a specific archive

### Step 1: Find the archives

```
GET http://localhost:9910/api/discovery
```

The response lists every deployed archive on the instance. Each archive entry includes a `functions` field showing the MCP handler entry point:

```json
{
  "discoverySchemaVersion": "1.2.0",
  "archives": {
    "analysisTools": {
      "archiveSchemaVersion": "1.2.0",
      "archiveUuid": "analysisTools_5338a235-078d-4d43-9b66-b27ee2feeb64",
      "functions": {
        "prodserver.mcp.internal.mcpHandler": {
          "signatures": [
            {
              "help": "Model Context Protocol entry point enabling AI agents to invoke MCP tools.",
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

The archive name (`analysisTools`) is the key you need for step 2. An archive hosts an MCP server if its functions include `prodserver.mcp.internal.mcpHandler`.

### Step 2: Get the tool signatures

Use the archive name from step 1 to query the `/signature` endpoint:

```
GET http://localhost:9910/analysisTools/signature
```

This returns the MATLAB-level signatures of every tool in the archive — parameter names, types, sizes, and whether each is required or optional:

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
      "name": ["sigma"],
      "type": ["double"],
      "kind": ["Required"],
      "order": ["sigma"],
      "validation": [
        {"size": "(1,1)", "type": "double", "fcn": []}
      ]
    }
  }
}
```

For multi-tool archives, the response contains one entry per tool. Note that the signatures contain MATLAB types, not JSON types. 

## Automatic Registration

Discovery is enabled by default. Every call to `build` embeds discovery metadata in the archive:

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="http://localhost:9910");
```

After deployment, the archive appears in the `/api/discovery` response and its tools are queryable via `/signature`. No additional configuration is needed.

If you don't want an archive to appear in the discovery endpoint, pass `discovery=false`:

```MATLAB
ctf = prodserver.mcp.build("principalStress", ...
    example=@() iprincipalStress([120 -50 80], "max"), ...
    discovery=false, ...
    server="http://localhost:9910");
```

The tool still functions normally — it responds to MCP requests at its endpoint. It does not appear in `/api/discovery` responses.

## Querying from MATLAB

The `prodserver.mcp.list` function wraps the two-step process:

```MATLAB
tools = prodserver.mcp.list("http://localhost:9910/analysisTools/mcp", "Tool")
```

## Configuration Requirements

Discovery must be enabled on the MPS instance by adding `--enable-discovery` to `main_config`. If disabled, `/api/discovery` returns an empty response. The `/signature` endpoint operates independently and requires no additional configuration.

## See Also

- [Building MCP Tools](../guides/building-tools.md) — deploying tools to MPS
- [`build` reference](../reference/build.md) — the `discovery` option
- [`list` reference](../reference/list.md) — the `Tool` option
- [MPS Discovery API](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html) — MathWorks documentation

--- Copyright 2026 The MathWorks, Inc. ---
