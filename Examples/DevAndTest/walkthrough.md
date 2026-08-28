# Debugging MCP Tools with Dev and Test

Use the MATLAB `productionServerArchiveCompiler` app to run a local development server with full interactive debugging support. Set breakpoints, inspect variables, and step through your MCP tool code before deploying to production.

## Prerequisites

- MATLAB with MATLAB Compiler SDK
- The `productionServerArchiveCompiler` app (included with MATLAB Compiler SDK)

## Build Routes for the Development Server

Use `prodserver.mcp.build` with the `stop` option to generate routes without creating a full CTF archive. Then copy the services file and set the routes environment variable.

```MATLAB
prodserver.mcp.build("primeSequence", wrapper="None", stop="Routes");
copyfile("deploy/McpServices.mat", ".");
setenv("PRODSERVER_ROUTES_FILE", "deploy/dev_test_routes.json");
```

## Create a Test Project

Launch `productionServerArchiveCompiler` and choose "Start a new project."

```MATLAB
productionServerArchiveCompiler
```

Add the MCP handlers (`mcpHandler`, `pingHandler`, `signatureHandler`) as the project's exported functions. Set the test archive name to match the archive name used by `prodserver.mcp.build` (by default, the function name).

## Start the Server

Press the **Test Client** button in the project toolstrip to open the server control panel. Start the server with the green arrow. The server indicates that handlers are available and the routes file is loaded.

Before starting your client, set breakpoints in your MATLAB code or the MCP Framework as desired.

## Test with a MATLAB Client

In a separate MATLAB desktop:

```MATLAB
seq = prodserver.mcp.call("http://localhost/primeSequence/mcp", "primeSequence", 11, "balanced")
```

The call executes through the development server. Any breakpoints you set will be hit, allowing full interactive debugging.

## Adapting for Your Own Tools

1. Copy the handler files from this folder into your tool's folder: `mcpHandler.m`, `pingHandler.m`, `signatureHandler.m`
2. Change directory to your tool's folder
3. Follow the steps above, substituting your function name and appropriate test calls

--- Copyright 2025-2026 The MathWorks, Inc. ---
