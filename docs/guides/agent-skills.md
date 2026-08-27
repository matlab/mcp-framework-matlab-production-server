# AI Agent Skills

Let your AI coding agent build and deploy MCP tools on your behalf. Instead of running MATLAB commands manually, describe what you want and the agent handles the build, deploy, and verification steps.

## Contents

- [Install](#install)
- [Using the build skill](#using-the-build-skill)
- [What the skill automates](#what-the-skill-automates)
- [What you still do manually](#what-you-still-do-manually)
- [Supported agents](#supported-agents)

---

## Install

Run this once in MATLAB to register the skill catalog:

```MATLAB
prodserver.mcp.agent.setup
```

Then in Claude Code:

1. Run `/plugins` and install the **mcp-framework** plugin
2. Run `/reload-plugins`
3. Verify with `/skills` — `/mps-mcp-build` should appear

## Using the Build Skill

Ask your agent to build a tool. For example:

> Build an MCP tool from principalStress.m and deploy it to localhost:9910.

Or with more options:

> Build cleanSignal.m and filterSignal.m as a multi-tool server on localhost:9910. Include the data file calibration.mat.

The agent reads your function, builds the archive, deploys it to MPS, verifies the deployment, and registers the MCP server so the tool is available in your next session.

You can also ask for resources:

> Build materialProps.m on localhost:9910 and add a resource at materials://steel with the contents from steel_properties.json.

## What the Skill Automates

| Step | What happens |
| :--- | :--- |
| Prerequisite check | Verifies MATLAB and MCP Framework are available |
| Build | Calls `prodserver.mcp.build` with the right arguments |
| Deploy | Uploads the archive to your MPS instance |
| Verify | Pings the server and lists the available tools |
| Register | Adds the MCP server to your Claude Code configuration |
| Incremental builds | Skips the build if nothing changed since last time |

The skill uses a build manifest to track source file hashes. If you ask it to rebuild and nothing has changed, it reports "up to date" and skips the expensive compilation step.

## What You Still Do Manually

- **Write your MATLAB function.** The skill builds what you give it — it does not write the function for you.
- **Start MATLAB Production Server.** The skill deploys to a running instance but does not start one.
- **Restart Claude Code.** After a new tool is registered, you need to start a new session for it to appear as a callable tool.
- **Test with real prompts.** After deployment, try a natural-language prompt that exercises the tool to confirm it works end to end.

## Supported Agents

| Agent | Status |
| :--- | :--- |
| Claude Code | Supported — skill installs via the plugin system |
| Codex CLI | Not yet supported |
| Gemini CLI | Not yet supported |

--- Copyright 2026 The MathWorks, Inc. ---
