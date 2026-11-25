# MCP Apps

Give your tools an interactive view, such as a plot or a form, that the host shows in the chat. An [MCP App](https://modelcontextprotocol.io/extensions/apps/overview) pairs tools with an HTML view. The view receives a tool's arguments and result from the host, and can call the server's tools itself.

Only hosts that support the MCP Apps extension, `io.modelcontextprotocol/ui`, show the view. Other hosts ignore it, and the tools work as before. See the [client matrix](https://modelcontextprotocol.io/extensions/client-matrix) for which hosts support it.

## Contents

- [Build a server with an app](#build-a-server-with-an-app)
- [Build the view](#build-the-view)
- [Read data from the view](#read-data-from-the-view)
- [Who sees uri2json](#who-sees-uri2json)
- [Errors](#errors)
- [Complete example](#complete-example)

---

## Build a Server with an App

Pass the view to `build` with the `app` option:

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("cleanSignal", ...
    app="app/dist/mcp-app.html", server="http://localhost:9910");
```

With `app`, `build`:

- Serves the view as a resource, `ui://<archive>/<archive>.html`, named `<archive>-app`, with MIME type `text/html;profile=mcp-app`.
- Links the view to every tool in `fcn`, through `_meta.ui.resourceUri` in each tool's definition.
- Adds the `uri2json` tool, which the view uses to read data.
- Makes the server announce the `io.modelcontextprotocol/ui` extension in its capabilities.

Check that the view is on the server:

```MATLAB
resources = prodserver.mcp.list(endpoint, "Resource");
cellfun(@(r) string(r.uri) + "  " + string(r.mimeType), resources)
ans =
    "ui://cleanSignal/cleanSignal.html  text/html;profile=mcp-app"
```

An archive has one view, which every tool in it shares. To give tools different views, build them into separate archives. The archive name is part of the view's URI, so `archive="cleanSignalApp"` serves `ui://cleanSignalApp/cleanSignalApp.html`.

`build` reads the view once and embeds it in the archive. Rebuild the archive whenever you change the view.

---

## Build the View

A host loads the view as one file, so every script and style must be inside it. Write the view with the [MCP Apps SDK](https://github.com/modelcontextprotocol/ext-apps), then build it with Vite and `vite-plugin-singlefile`, which puts everything into one HTML file.

Skip the SDK's server helpers: `build` is the server. The [Signal Filter App](../../Examples/SignalFilterApp/walkthrough.md#build-the-view) shows the toolchain, and [The Prompt Behind the View](../../Examples/SignalFilterApp/prompt.md) shows how to have an LLM write the view.

---

## Read Data from the View

The view runs in the host, not on the server, so it can't read a tool's `file:` URLs itself. It calls `uri2json` with the URL instead:

```typescript
const result = await app.callServerTool({
  name: "uri2json",
  arguments: { uri: url },
});
const data = (result.structuredContent as any)?.result?.data;
```

`uri2json` takes `{"uri": <url>}` and returns the data in `structuredContent.result.data`. It reads any URL the server's [wrapper functions](../concepts/wrapper-functions.md#url-scheme) can. Numbers come as a tool's plain JSON output sends them: always an array, even of one value, with NaN as `null`, and `Inf` and `-Inf` as the text `"Inf"` and `"-Inf"`.

A call that fails, to `uri2json` or to one of your tools, doesn't throw. It returns a result with `isError` set, and the server's message in `content`. Check `isError` before you read the data.

For the URI of one of the server's own resources, `uri2json` returns the resource itself instead: `structuredContent.result` has `uri`, `mimeType`, and `text` or `blob`.

---

## Who Sees uri2json

`uri2json` is for the view, not the model. The server offers it only to clients that declare MCP Apps support, `io.modelcontextprotocol/ui`, in their capabilities:

| Where | Clients that declare MCP Apps support | Other clients |
| :--- | :--- | :--- |
| `tools/list` | Listed, with `_meta.ui.visibility: ["app"]` | Not listed |
| `tools/call` | Runs | The unknown-tool error, counted in `MCP_uri2json_Refused` |
| `/signature` | Listed, for a request with a `2025-06-18` session that declared support | Not listed |

A host that supports MCP Apps reads `visibility: ["app"]` and keeps the tool out of the model's tool list. Only the view can call it.

`/signature` learns a client's capabilities only from its `2025-06-18` session, so a request with no session doesn't see `uri2json`. That includes every `2026-07-28` client. `MCP_uri2json_Refused` counts only on a server with an app: on any other, `uri2json` is an unknown tool. See [Server Metrics](./server-metrics.md).

MATLAB clients don't declare MCP Apps support. `prodserver.mcp.list` doesn't show `uri2json`, and `prodserver.mcp.call` can't call it.

Because the tool list depends on the client, an app server's `tools/list` result under `2026-07-28` carries `cacheScope: private` and `ttlMs: 0`, so no cache shares it between clients. See [Protocol Conformance](../concepts/protocol-conformance.md).

`uri2json` returns the raw data at any URL the server can reach. A client that connects to the server directly can claim MCP Apps support and call it. See [Security](../concepts/security.md#mcp-apps-and-uri2json) for what that means and how to limit it.

---

## Errors

| Identifier | Cause |
| :--- | :--- |
| `prodserver:mcp:FileNotFound` | The `app` file doesn't exist. |
| `prodserver:mcp:NotAFile` | The `app` path is a folder. |
| `prodserver:mcp:FrameworkShadowed` | MATLAB finds a `uri2json` of your own before the framework's: in the current folder, or, in an Add-On install, in a folder ahead of the framework's on the path. Rename the file, or change folder or remove that folder from the path, as the message says. |
| `prodserver:mcp:ReservedToolName` | A function or tool is named `uri2json` or `read_mcp_resource`, the framework's own tools. Rename the function; if the name came from the `tool` option, choose another. Applies with or without `app`. |

---

## Complete Example

The [Signal Filter App](../../Examples/SignalFilterApp/walkthrough.md) builds a view for the `cleanSignal` tool that plots a signal before and after filtering, and runs more cleaning passes from the view. It covers the toolchain, the build, and connecting VS Code.

--- Copyright 2026 The MathWorks, Inc. ---
