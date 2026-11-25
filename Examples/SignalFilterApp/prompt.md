# The Prompt Behind the View

The view in [`app/`](./app/) was written by an LLM coding agent (Claude Code), with the `create-mcp-app` skill from the [MCP Apps SDK](https://github.com/modelcontextprotocol/ext-apps) installed. This page shows the prompts that produced it, and what to add when you write your own.

An LLM won't write the same code twice. The same prompt gives you a working view, not this one. The source in `app/` is the reference result.

## Install the Skill

The SDK's agent skills know the SDK's API, the single-file build and the view's life cycle. In Claude Code:

```
/plugin marketplace add modelcontextprotocol/ext-apps
/plugin install mcp-apps@modelcontextprotocol-ext-apps
```

For other agents, see the SDK's [agent skills guide](https://github.com/modelcontextprotocol/ext-apps/blob/main/docs/agent-skills.md).

## The Prompts

The view took two prompts. The first describes the app and says what not to build:

> I'd like to make a plan to build a demo application for the cleanSignal tool. The application should allow me to choose a file containing the signal to clean and to specify the frequency of the periodic noise to remove. We won't need the standalone server part of the app because we're going to serve the UI resource from an MCP server built with the build command. Take a look at the create-mcp-app skill.

The second, once the agent had looked at the tool, describes the display:

> I'd like the UI to display a composite plot — the original signal only, the clean signal only or both signals (each signal plotted in a different color). There should be a radio button panel that enables the user to pick the display. And I'd like to be able to send the signal through multiple cleaning passes.

The rest of the session was review and testing: deploying the server, opening the view in a host, and correcting what didn't work.

## What the Agent Needs to Know

The `create-mcp-app` skill builds a complete app: a view and a Node.js MCP server. With the framework, `prodserver.mcp.build` is the server. Tell the agent so, or it builds a server you don't need.

The agent also needs these facts, which it can't find out from the skill. Give them in the first prompt:

- **The tool's input schema.** Paste the tool's `inputSchema`, or write it to a file and point the agent at it. The view calls the tool with these argument names. `cleanSignal` was first written with an input named `period`, and the view's calls failed until the agent learned the name was `frequency`.
- **Where the results are.** A tool with a generated [wrapper](../../docs/concepts/wrapper-functions.md) returns URLs, not data: `cleanSignal` returns `structuredContent.cleanURL`.
- **How to read a URL.** The view can't read `file:` URLs itself. A server built with `app` has a `uri2json` tool: call it with `{"uri": <url>}`, and the data is in `structuredContent.result.data`. For the URI of one of the server's resources, such as `ui://...`, the result is the resource itself instead: `uri`, `mimeType`, and `text` or `blob`.
- **The build.** One self-contained HTML file, built with Vite and `vite-plugin-singlefile`. The toolchain is installed in a parent folder (`Examples/package.json` here), so the app folder needs no `package.json`.

`build` writes no definition file to show the agent. Get the input schema from the deployed server with `prodserver.mcp.list`:

```MATLAB
tools = prodserver.mcp.list(endpoint, "Tool");
t = tools{cellfun(@(t) strcmp(t.name, "cleanSignal"), tools)};
writelines(jsonencode(t.inputSchema, PrettyPrint=true), "cleanSignalSchema.json")
```

## A Prompt for Your Own View

Combining the two prompts with these facts:

> Use the create-mcp-app skill to write the view of an MCP App for the `cleanSignal` tool. Write only the view: the MCP server is built by `prodserver.mcp.build` from the MCP Framework for MATLAB Production Server, which serves the view as a `ui://` resource. The tool's input schema is in `cleanSignalSchema.json`.
>
> The tool reads a signal from `noisyURL`, removes the noise at `frequency` Hz, and writes the result to `cleanURL`. Its result has the output URL in `structuredContent.cleanURL`. To read the data at a URL, call the server's `uri2json` tool with `{"uri": <url>}`; the data is in `structuredContent.result.data`.
>
> The view shows the signal file and lets me choose the frequency to remove. It plots the original signal, the clean signal, or both in different colors, chosen with radio buttons. I can send the signal through more cleaning passes, each at its own frequency, and remove passes.
>
> Build the view into one HTML file with Vite and vite-plugin-singlefile, in `app/dist/mcp-app.html`. Use the toolchain installed in the parent folder.

Change the tool, the file names and the display for your own tool.

--- Copyright 2026 The MathWorks, Inc. ---
