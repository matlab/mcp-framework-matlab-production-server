function setup()
%setup Install MCP Framework agent skills for available AI coding agents.
%
%   prodserver.mcp.agent.setup installs the MCP Framework build skill so
%   that it is available in AI coding agents (Claude Code, etc.) regardless
%   of the current working directory.
%
%   The skill enables the agent to build and deploy MCP tools from MATLAB
%   functions to MATLAB Production Server.
%
%   Supported agents:
%     - Claude Code (via marketplace plugin)

% Copyright 2026 The MathWorks, Inc.

    repoRoot = prodserver.mcp.internal.packageFolder();
    skillsDir = fullfile(repoRoot, "skills-catalog");

    if ~isfolder(skillsDir)
        error("prodserver:mcp:SkillsNotFound", ...
            "Cannot find skills-catalog at '%s'.", skillsDir);
    end

    installedAgents = string.empty;

    % --- Claude Code ---
    if isClaudeAvailable()
        installForClaude(repoRoot);
        installedAgents(end+1) = "Claude Code";
    end

    % --- Future agents ---

    if isempty(installedAgents)
        warning("prodserver:mcp:NoAgentsFound", ...
            "No supported AI agents detected. Install Claude Code " + ...
            "(https://claude.ai/claude-code) and try again.");
    else
        fprintf("MCP Framework marketplace registered for: %s\n", ...
            strjoin(installedAgents, ", "));
        fprintf("\nNext steps:\n");
        fprintf("  1. In Claude Code, install the plugin:  /plugins  → mcp-framework\n");
        fprintf("  2. Reload plugins:  /reload-plugins\n");
        fprintf("  The /mps-mcp-build skill will then appear in /skills.\n");
    end
end

function tf = isClaudeAvailable()
    [status, ~] = system("claude --version");
    tf = (status == 0);
end

function installForClaude(repoRoot)
    repoRoot = replace(repoRoot, "\", "/");
    cmd = sprintf('claude plugin marketplace add "%s"', repoRoot);
    [status, output] = system(cmd);
    if status ~= 0
        warning("prodserver:mcp:ClaudeInstallFailed", ...
            "claude plugin marketplace add failed (exit %d):\n%s\n" + ...
            "Attempting manual registration.", status, output);
        manualClaudeInstall(repoRoot);
    end
end

function manualClaudeInstall(repoRoot)
    claudeDir = fullfile(getenv("USERPROFILE"), ".claude", "plugins");
    if isempty(getenv("USERPROFILE"))
        claudeDir = fullfile(getenv("HOME"), ".claude", "plugins");
    end

    if ~isfolder(claudeDir)
        [ok, msg] = mkdir(claudeDir);
        if ~ok
            error("prodserver:mcp:CannotCreatePluginDir", ...
                "Cannot create %s: %s", claudeDir, msg);
        end
    end

    knownFile = fullfile(claudeDir, "known_marketplaces.json");
    if isfile(knownFile)
        txt = fileread(knownFile);
        known = jsondecode(txt);
    else
        known = struct("marketplaces", {{}});
    end

    name = "mcp-framework-matlab-production-server";
    alreadyRegistered = false;
    if isfield(known, "marketplaces") && ~isempty(known.marketplaces)
        for k = 1:numel(known.marketplaces)
            if isfield(known.marketplaces{k}, "name") && ...
                    strcmp(known.marketplaces{k}.name, name)
                alreadyRegistered = true;
                break;
            end
        end
    end

    if ~alreadyRegistered
        entry.name = name;
        entry.source = repoRoot;
        entry.installedAt = fullfile(repoRoot);
        if isfield(known, "marketplaces")
            known.marketplaces{end+1} = entry;
        else
            known.marketplaces = {entry};
        end
        txt = jsonencode(known, PrettyPrint=true);
        fid = fopen(knownFile, "w");
        if fid == -1
            error("prodserver:mcp:CannotWriteMarketplace", ...
                "Cannot write to %s.", knownFile);
        end
        fwrite(fid, txt);
        fclose(fid);
        fprintf("  Registered marketplace in %s\n", knownFile);
    else
        fprintf("  MCP Framework already registered in Claude Code.\n");
    end
end
