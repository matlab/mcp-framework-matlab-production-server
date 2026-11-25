# prodserver.mcp.agent.setup
```MATLAB
prodserver.mcp.agent.setup
```
Register the MCP Framework skill marketplace for available AI coding agents. This is the first step toward making the `/mps-mcp-build` skill available in supported agents (currently Claude Code).

The function detects which supported agents are installed and registers the MCP Framework skill catalog with each. For Claude Code, it needs the `claude` CLI on the system path and registers the catalog with `claude plugin marketplace add`, and only that way. It writes Claude Code's files itself only to repair one that an earlier version broke: see below. If the marketplace is already registered from this copy of the framework, it says so and changes nothing. If it's registered from another folder, such as an earlier clone or install that you have since replaced, `setup` registers this copy in its place, with `claude plugin marketplace remove` and then `add`, and says which folder it pointed to. Otherwise Claude Code would go on reading the skills from the old folder, or find none if it's gone. If the `add` fails, `setup` registers the old folder again, and the error says whether it could. An entry that 1.6.0 renamed to `mcp_framework_matlab_production_server` is replaced the same way, even if it points to this copy. One registered from another kind of source, such as GitHub, is left as it is. If the command fails, `setup` raises `prodserver:mcp:ClaudeInstallFailed`, with Claude's message and the steps to take by hand. Without the `claude` CLI, it warns that no supported agents were found and changes nothing.

### Repairing a configuration earlier versions broke

Up to version 1.6.0, when `claude plugin marketplace add` failed, `setup` wrote the marketplace into Claude Code's `known_marketplaces.json` itself, in a form Claude Code rejects. That command always failed for an Add-Ons install, which didn't ship the marketplace file. Claude Code then reports `Marketplace configuration file is corrupted: marketplaces: Invalid input: expected object, received array`, and no marketplace works, not only this one.

Running `setup` again repairs the file. It removes the top-level `"marketplaces"` entry if every item in it is this framework's, keeps the original as `known_marketplaces.json.bak` (or, if that exists, `known_marketplaces.json.<yyyyMMddTHHmmss>.bak`), and changes nothing else in the file. It looks in `CLAUDE_CONFIG_DIR` if that's set, else `~/.claude`. If the entry has anything else in it, `setup` warns (`prodserver:mcp:UnknownMarketplacesKey`) and leaves the file alone.

Those versions also rewrote the rest of the file, and in doing so changed `-` to `_` in the names of other marketplaces, such as `claude-plugins-official`. `setup` can't tell what the names were. If Claude Code reports a marketplace missing after the repair, remove its entry and add it again with `claude plugin marketplace add`.

### Without a marketplace

Claude Code won't add a marketplace from a network drive. If the framework is installed on one, for example because your MATLAB Add-Ons folder is on a network share, `setup` fails with Claude's message `its location is on a network drive`. Use the skill without a marketplace instead.

To use the skill without registering a marketplace, copy the folder `skills-catalog/mcp-framework/mps-mcp-build` from the framework's install folder into your Claude Code skills folder: `~/.claude/skills`, or `skills` in `CLAUDE_CONFIG_DIR`.

After running this function, install the plugin and reload it in your agent session before the skill becomes available. See the Examples section below for the complete workflow.

### Inputs
None.

### Outputs
None. Prints status messages to the command window.

# Examples

Register the marketplace and install the skill.
```MATLAB
prodserver.mcp.agent.setup
```
Output:
```
MCP Framework marketplace registered for: Claude Code

Next steps:
  1. In Claude Code, install the plugin:  /plugin  → mcp-framework
  2. Reload plugins:  /reload-plugins
  The /mps-mcp-build skill will then appear in /skills.
```

Then in Claude Code:
1. Run `/plugin` and install the **mcp-framework** plugin
2. Run `/reload-plugins`
3. Verify with `/skills` — the `/mps-mcp-build` skill should now be listed

***

If no supported agents are found:
```MATLAB
prodserver.mcp.agent.setup
```

Output:
```
Warning: No supported AI agents detected. Install Claude Code
(https://claude.ai/claude-code) and try again.
```

# Supported Agents

| Agent | Registration method |
| :--- | :--- |
| Claude Code | `claude plugin marketplace add`. Requires the `claude` CLI. |

# See Also
* [Client Configuration](../guides/client-configuration.md) — manual Claude configuration
* [build](./build.md) — build an MCP tool from a MATLAB function

--- Copyright 2026 The MathWorks, Inc. ---
