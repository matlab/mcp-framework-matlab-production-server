# prodserver.mcp.agent.setup
```MATLAB
agent.setup
```
Register the MCP Framework skill marketplace for available AI coding agents. This is the first step toward making the `/mps-mcp-build` skill available in supported agents (currently Claude Code).

The function detects which supported agents are installed and registers the MCP Framework skill catalog with each. If the `claude` CLI is available, it uses `claude plugin marketplace add` to register the catalog. Otherwise it writes directly to the Claude Code plugin registry.

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
  1. In Claude Code, install the plugin:  /plugins  → mcp-framework
  2. Reload plugins:  /reload-plugins
  The /mps-mcp-build skill will then appear in /skills.
```

Then in Claude Code:
1. Run `/plugins` and install the **mcp-framework** plugin
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
| Claude Code | `claude plugin marketplace add` (or direct file write to `~/.claude/plugins/`) |

# See Also
* [Client Configuration](../guides/client-configuration.md) — manual Claude configuration
* [build](./build.md) — build an MCP tool from a MATLAB function

--- Copyright 2026 The MathWorks, Inc. ---
