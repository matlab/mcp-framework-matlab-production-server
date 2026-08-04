# prodserver.mcp.agent.setup
```MATLAB
agent.setup
```
Install MCP Framework agent skills for available AI coding agents. After running this function, the `/mps-mcp-build` skill is available in supported agents (currently Claude Code) regardless of the current working directory. Restart your agent session after installation for changes to take effect.

The function detects which supported agents are installed and registers the MCP Framework skills with each. If the `claude` CLI is available, it uses `claude plugin marketplace add` to register the skill catalog. Otherwise it writes directly to the Claude Code plugin registry.

### Inputs
None.

### Outputs
None. Prints status messages to the command window.

# Examples

Install skills for all detected agents:
```MATLAB
prodserver.mcp.agent.setup
```
Output:
```
MCP Framework skills installed for: Claude Code
Restart your agent session for changes to take effect.
```
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
* [ConfigureClaude](./ConfigureClaude.md) — manual Claude configuration
* [build](./build.md) — build an MCP tool from a MATLAB function

--- Copyright 2026 The MathWorks, Inc. ---
