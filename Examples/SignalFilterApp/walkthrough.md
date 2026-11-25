# Signal Filter App

An MCP App adds a graphical user interface (GUI) to an MCP tool. This GUI is called a "view". It receives the tool's arguments and results and can call the server's tools itself. You write the view, in HTML and TypeScript, often with the help of an LLM. Not all hosts support MCP Apps yet -- those that don't simply ignore the view and the tool works as before. 

This example builds an [MCP App](https://modelcontextprotocol.io/extensions/apps/overview) for the `cleanSignal` tool from [Periodic Noise](../Periodic%20Noise/walkthrough.md). The view displays a plot of the signal, before and after filtering, that runs inside the chat. 

## Requirements

- Everything [Periodic Noise](../Periodic%20Noise/walkthrough.md) needs, including Signal Processing Toolbox.
- [Node.js](https://nodejs.org), to build the view. Node.js is needed only on the machine that builds the view, not on the server.
- A host that shows MCP Apps. This example uses VS Code with GitHub Copilot. See the [client matrix](https://modelcontextprotocol.io/extensions/client-matrix) for others.

## The Tool

`cleanSignal` removes periodic noise at one frequency from a given signal:

```MATLAB
function clean = cleanSignal(noisy,frequency)
%cleanSignal Remove periodic noise from a signal using a Butterworth notch
%filter.
    arguments (Input)
        % Noisy signal
        noisy double
        % Noise frequency to remove, in Hz (e.g. 60 for mains hum).
        % Between 1 and 499 Hz: the filter's stop band is 2 Hz wide and
        % must fit below half the 1000 Hz sample rate.
        %#schema { "exclusiveMinimum": 1, "exclusiveMaximum": 499 }
        frequency (1,1) double {mustBeGreaterThan(frequency,1), mustBeLessThan(frequency,499)}
    end
    arguments (Output)
        % Filtered signal
        clean double
    end
    ...
end
```

The `%#schema` line puts the frequency range into the tool's schema, so the LLM knows it. Validators in an arguments block are enforced when the tool runs, but don't appear in the schema: see [Schemas](../../docs/concepts/schemas.md).

As in the Periodic Noise example, the framework generates a wrapper that passes the signals as file URLs: the tool's inputs are `noisyURL`, `frequency` and `cleanURL`, and its result is the URL of the clean signal.

## The View

The example's view is in [`app/`](./app/). It consists of TypeScript source files which are built into a deployable HTML file.

| File | Purpose |
| :--- | :--- |
| `mcp-app.html` | The page: the controls and the chart |
| `src/main.ts` | Connects to the host, and handles the tool's arguments and result |
| `src/passes.ts` | Reads signals with `uri2json`, and runs the cleaning passes |
| `src/chart.ts` | Draws the signals on a canvas |
| `src/global.css` | Styles, following the host's theme |
| `vite.config.ts`, `tsconfig.json` | Build settings |

The view uses the [MCP Apps SDK](https://github.com/modelcontextprotocol/ext-apps), `@modelcontextprotocol/ext-apps`, to talk to the host. When the host sends the tool's result, the view reads the original and clean signals and plots them. The **Add pass** button adds another frequency to remove: the view calls `cleanSignal` itself, once for each pass, each pass cleaning the previous pass's result.

## Write the View with an LLM

The view was written by an LLM, from two short prompts. [The Prompt Behind the View](./prompt.md) shows them, how to install the SDK's `create-mcp-app` skill, and what the LLM needs to know about your tool.

To write a view by hand, start with the SDK's [quickstart](https://apps.extensions.modelcontextprotocol.io/api/documents/quickstart.html) and [API documentation](https://apps.extensions.modelcontextprotocol.io/api/). Skip the server: `build` replaces the SDK's server helpers. The [MCP Apps specification](https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx) defines the protocol between view and host.

## Build the View

A host loads the view as one file, so every script and style must be inside it. Vite compiles the TypeScript, and `vite-plugin-singlefile` puts everything into one HTML file.

The build tools are listed in [`Examples/package.json`](../package.json), which every example app shares. Install them once, in the `Examples` folder:

```
cd Examples
npm install
```

Then build the view:

```
cd SignalFilterApp/app
npx vite build
```

The view is `app/dist/mcp-app.html`, about 460 KB. Rebuild it whenever you change the view.

## Build and Deploy the Server

Pass the view to `build` with the `app` option:

```MATLAB
cleanSignalApp = fullfile(pwd, "app", "dist", "mcp-app.html");
[ctf, endpoint] = prodserver.mcp.build("cleanSignal", app=cleanSignalApp, server="http://localhost:9910");
```
If you are deploying to a shared server, give the archive a unique name with `build`'s `archive` option -- for example by appending your user name. The `deploy` function replaces an archive with the same name, even one someone else deployed. The archive name is part of the view's `ui://` URI and the server's URL, so with another name, the URI and URLs below change to match.

[Periodic Noise](../Periodic%20Noise/walkthrough.md) also deploys an archive named `cleanSignal`. If you've already run it on this server, give this archive another name with `archive`, such as `cleanSignalApp`: unless the server is in [multi-MCOS mode](../../docs/reference/deploy.md#several-archives-on-one-server), `deploy` can't replace an archive a worker has loaded, and fails with `prodserver:mcp:NeedMultiMCOSMode`.

With the `app` option, `build` will:

- Create a resource for the view: `ui://cleanSignal/cleanSignal.html`, with MIME type `text/html;profile=mcp-app`.
- Add `_meta.ui.resourceUri` to the definition of `cleanSignal`.
- Add the `uri2json` tool, which the view uses to read the signals. Only clients that support MCP Apps are offered it, and their hosts keep it from the model, so it's absent from the tool list `prodserver.mcp.list` shows you.
- Make the server announce the MCP Apps extension, `io.modelcontextprotocol/ui`, to clients.

## Verify Deployment

```MATLAB
prodserver.mcp.ping(endpoint)
ans =
    true

resources = prodserver.mcp.list(endpoint, "Resource");
cellfun(@(r) string(r.uri) + "  " + string(r.mimeType), resources)
ans =
    "ui://cleanSignal/cleanSignal.html  text/html;profile=mcp-app"
```

The tool works from MATLAB as before. MATLAB doesn't show the view:

```MATLAB
noisyURL = "file:" + fullfile(pwd, "openloopVoltage.csv");
cleanURL = "file:" + fullfile(pwd, "output", "openloopVoltage_clean.csv");
prodserver.mcp.call(endpoint, "cleanSignal", noisyURL, 60, cleanURL=cleanURL)
```

These `file:` URLs name files on the server's machine: MATLAB Production Server reads and writes them itself. Building them from your own folder works when the server runs on your machine, or can reach that folder at the same path. For a remote server, see [URL Scheme](../../docs/concepts/wrapper-functions.md#url-scheme).

## Connect VS Code

Create `.vscode/mcp.json` in your project:

```json
{
  "servers": {
    "cleanSignal": {
      "url": "http://localhost:9910/cleanSignal/mcp",
      "type": "http"
    }
  }
}
```

VS Code shows a status decoration above the server name in `mcp.json`. Confirm that it shows the server as connected. See [Client Configuration](../../docs/guides/client-configuration.md) for other clients.

## Try It

In Copilot Chat, in agent mode:

> Remove the 60 Hz periodic noise from the signal in openloopVoltage.csv in the SignalFilterApp example folder.

Copilot calls `cleanSignal`, and VS Code shows the view in the chat. Choose **Original**, **Clean** or **Both** to change the plot. To clean the signal again, enter another frequency and choose **Add pass**; remove a pass with its **×**.

The view writes each pass's result next to the original signal, as `openloopVoltage_clean_pass0.csv`, `openloopVoltage_clean_pass1.csv` and so on, so the server must be able to write to that folder.

When you reopen the chat, VS Code shows the view again, and the view reads the signal files again. If you've deleted them, it can't plot them.

## Your Own Apps

To add a view to another tool:

1. Write the view in its own folder. [The Prompt Behind the View](./prompt.md) shows how to have an LLM write it.
2. Build it into one HTML file.
3. Build the tool with `app=<path to the HTML file>`.

An app in the `Examples` folder can use the shared toolchain. Elsewhere, copy [`Examples/package.json`](../package.json) to the folder above your apps and run `npm install` there.

`build` gives every tool built with it the same view. To give tools different views, build them into separate archives.

## See Also

- [`build`](../../docs/reference/build.md)
- [Periodic Noise](../Periodic%20Noise/walkthrough.md)
- [MCP Apps overview](https://modelcontextprotocol.io/extensions/apps/overview)
- [MCP Apps SDK](https://github.com/modelcontextprotocol/ext-apps)

--- Copyright 2026 The MathWorks, Inc. ---
