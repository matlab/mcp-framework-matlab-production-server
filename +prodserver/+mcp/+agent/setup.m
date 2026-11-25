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
%
%   For Claude Code, setup registers the framework's marketplace with
%   claude plugin marketplace add, and only that way: Claude Code's own
%   files are Claude Code's to write. If the command fails, setup raises
%   prodserver:mcp:ClaudeInstallFailed with Claude's message and the steps
%   to take by hand. If the marketplace is already registered from another
%   folder, such as an earlier clone or install of the framework, setup
%   registers this copy in its place (claude plugin marketplace remove,
%   then add); one registered from another kind of source, such as GitHub,
%   it leaves alone. If the add then fails, setup registers the earlier
%   folder again, and says so in the error. An entry that version 1.6.0
%   renamed to mcp_framework_matlab_production_server is replaced the same
%   way, wherever it points.
%
%   Versions up to 1.6.0 wrote the marketplace into Claude Code's
%   known_marketplaces.json themselves when that command failed, in a form
%   Claude Code rejects: a top-level "marketplaces" array. Claude Code then
%   reports the file corrupted and no marketplace works. setup removes
%   that array, keeping a copy of the file, if every entry in it is the
%   framework's; otherwise it warns and leaves the file alone.

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
        repairKnownMarketplaces();
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
        fprintf("  1. In Claude Code, install the plugin:  /plugin  → mcp-framework\n");
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
    name = marketplaceName();

    % Already registered (claude plugin marketplace add would refuse it):
    % from this copy of the framework, leave it; from another, such as a
    % clone the user has since replaced with an Add-Ons install, register
    % this one instead, or Claude Code goes on reading the skills there.
    [source, readable, registered] = registeredSource(name);
    if ~readable
        % Claude Code's file can't be read: ask Claude, which can't say
        % where it points. The name must match whole, not as part of
        % another marketplace's.
        [status, listed] = system("claude plugin marketplace list");
        source = "";
        if status == 0 && ~isempty(regexp(plainText(listed), ...
                "(^|[^\w-])" + regexptranslate("escape", name) + ...
                "($|[^\w-])", "once"))
            source = "unknown";
        end
    end
    % Under another name, it is 1.6.0's renaming, which no command names
    % as the framework's: replace it, even from this folder.
    renamed = registered ~= name;
    removed = "";
    if ~renamed && (source == "unknown" || (strlength(source) > 0 && ...
            samePath(source, repoRoot)))
        fprintf("  MCP Framework already registered in Claude Code.\n");
        return
    elseif strlength(source) > 0
        [status, output] = system(sprintf( ...
            'claude plugin marketplace remove "%s"', registered));
        if status ~= 0
            error("prodserver:mcp:ClaudeInstallFailed", ...
                "The MCP Framework marketplace is registered in Claude " + ...
                "Code from %s, not from this copy, %s, and claude " + ...
                "plugin marketplace remove failed (exit %d):\n%s\n\n" + ...
                "Run it yourself, then run setup again.", source, ...
                repoRoot, status, strtrim(plainText(output)));
        end
        fprintf("  Re-registering the MCP Framework marketplace: it " + ...
            "pointed to %s.\n", source);
        removed = source;
    end

    cmd = sprintf('claude plugin marketplace add "%s"', repoRoot);
    [status, output] = system(cmd);
    if status ~= 0
        skill = fullfile(repoRoot, "skills-catalog", "mcp-framework", ...
            "mps-mcp-build");
        error("prodserver:mcp:ClaudeInstallFailed", ...
            "claude plugin marketplace add failed (exit %d):\n%s\n\n" + ...
            "%sTo register the marketplace yourself, fix the problem " + ...
            "above and run:\n  claude plugin marketplace add ""%s""\n" + ...
            "Or, without a marketplace, copy the skill folder %s into " + ...
            "your Claude Code skills folder (~/.claude/skills, or " + ...
            "skills in CLAUDE_CONFIG_DIR).", ...
            status, strtrim(plainText(output)), restore(removed), ...
            repoRoot, skill);
    end
end

function said = restore(removed)
%restore Register REMOVED again, the folder setup unregistered before an
%   add that failed, so the user isn't left with no marketplace. SAID is
%   what happened, for the error message: "" if nothing was removed.
    said = "";
    if strlength(removed) == 0
        return
    end
    status = 1;
    if isfolder(removed)
        [status, ~] = system(sprintf( ...
            'claude plugin marketplace add "%s"', removed));
    end
    if status == 0
        said = sprintf("The marketplace is registered from %s again, " + ...
            "as it was before setup ran.\n\n", removed);
    else
        said = sprintf("setup removed the registration from %s first, " + ...
            "and couldn't restore it. To restore it, run:\n" + ...
            "  claude plugin marketplace add ""%s""\n\n", removed, removed);
    end
end

function [source, readable, registered] = registeredSource(name)
%registeredSource Where marketplace NAME is registered in Claude Code, as
%   its known_marketplaces.json says: the folder of a directory source;
%   "unknown" for a source of another kind or none this can read; "" if
%   it isn't registered. Only read, never written. readable is false if
%   the file exists but can't be read as JSON: then nothing is known.
%   REGISTERED is the name it is registered under: NAME, or, if only the
%   entry 1.6.0 renamed is there, that name, as Claude Code knows it.
    source = "";
    readable = true;
    registered = name;
    file = fullfile(claudeConfigDir(), "plugins", "known_marketplaces.json");
    if ~isfile(file)
        return
    end
    try
        txt = string(prodserver.mcp.internal.readUTF8(file));
        known = jsondecode(txt);
    catch
        readable = false;
        return
    end
    if ~isstruct(known)
        return
    end
    % By the key as written: jsondecode gives "a-b" and "a_b" the same
    % field, and 1.6.0 rewrote this file through jsondecode, renaming the
    % framework's entry. Claude Code knows a renamed one by its new name.
    [first, last] = topLevelMember(txt, name);
    if isempty(first)
        renamed = string(matlab.lang.makeValidName(name));
        [first, last] = topLevelMember(txt, renamed);
        if isempty(first)
            return
        end
        registered = renamed;
    end
    source = "unknown";
    try
        entry = jsondecode(extractAfter(extractBetween(txt, first, last), ":"));
    catch
        return
    end
    if isstruct(entry) && isfield(entry, "source") && ...
            isstruct(entry.source) && isfield(entry.source, "path") && ...
            prodserver.mcp.validation.istext(entry.source.path)
        kind = "";
        if isfield(entry.source, "source")
            kind = string(entry.source.source);
        end
        if kind == "" || kind == "directory"
            source = string(entry.source.path);
        end
    end
end

function tf = samePath(a, b)
% True if folders A and B are the same, however their separators and
% trailing separators differ. Case matters only where file names' does.
    a = regexprep(replace(string(a), "\", "/"), "/+$", "");
    b = regexprep(replace(string(b), "\", "/"), "/+$", "");
    if ispc || ismac
        tf = strcmpi(a, b);
    else
        tf = a == b;
    end
end

function name = marketplaceName()
% The name in .claude-plugin/marketplace.json.
    name = "mcp-framework-matlab-production-server";
end

function repairKnownMarketplaces()
%repairKnownMarketplaces Remove the "marketplaces" array that versions up
%   to 1.6.0 added to Claude Code's known_marketplaces.json, if every entry
%   in it is the framework's. By editing the text, not by decoding and
%   encoding the file: jsondecode turns keys into MATLAB names, so
%   my-marketplace would come back as my_marketplace.
    file = fullfile(claudeConfigDir(), "plugins", "known_marketplaces.json");
    if ~isfile(file)
        return
    end
    txt = string(prodserver.mcp.internal.readUTF8(file));
    [first, last] = topLevelMember(txt, "marketplaces");
    if isempty(first)
        return
    end

    % Ours: an array of entries {name, source, installedAt}, every one
    % named for the framework's marketplace.
    value = extractBetween(txt, first, last);
    value = extractAfter(value, ":");
    try
        entries = jsondecode(value);
    catch
        entries = [];
    end
    if isstruct(entries)
        entries = num2cell(entries);
    end
    ours = iscell(entries) && ~isempty(entries) && all(cellfun(@(e) ...
        isstruct(e) && isfield(e, "name") && isfield(e, "installedAt") && ...
        string(e.name) == marketplaceName(), entries));
    if ~ours
        warning("prodserver:mcp:UnknownMarketplacesKey", ...
            "%s has a top-level ""marketplaces"" member that " + ...
            "Claude Code may reject, and it isn't one the MCP Framework " + ...
            "wrote. Leaving it alone.", file);
        return
    end

    backup = file + ".bak";
    if isfile(backup)
        backup = file + "." + string(datetime("now", ...
            Format="yyyyMMdd'T'HHmmss")) + ".bak";
    end
    copyfile(file, backup);
    prodserver.mcp.internal.writeUTF8(file, ...
        removeMember(txt, first, last), TrailingLineEnding=false);
    fprintf("  Repaired %s: removed the ""marketplaces"" entry an " + ...
        "earlier MCP Framework setup wrote. The original is in %s.\n", ...
        file, backup);
end

function folder = claudeConfigDir()
% Claude Code's configuration folder: CLAUDE_CONFIG_DIR, else ~/.claude.
    folder = string(getenv("CLAUDE_CONFIG_DIR"));
    if strlength(folder) == 0
        home = string(getenv("USERPROFILE"));
        if strlength(home) == 0
            home = string(getenv("HOME"));
        end
        folder = fullfile(home, ".claude");
    end
end

function [first, last] = topLevelMember(txt, key)
%topLevelMember The span of member KEY of the top-level JSON object TXT:
%   from the opening quote of its key to the last character of its value.
%   Empty if there's no such member. Strings are skipped whole, so a key
%   or bracket inside one doesn't count.
    first = []; last = [];
    c = char(txt);
    depth = 0; i = 1; n = numel(c);
    while i <= n
        switch c(i)
            case '"'
                j = stringEnd(c, i);
                if depth == 1 && strcmp(c(i+1:j-1), key)
                    k = j + 1;
                    while k <= n && isspace(c(k)), k = k + 1; end
                    if k <= n && c(k) == ':'
                        first = i;
                        last = valueEnd(c, k + 1);
                        return
                    end
                end
                i = j;
            case {'{', '['}
                depth = depth + 1;
            case {'}', ']'}
                depth = depth - 1;
        end
        i = i + 1;
    end
end

function j = stringEnd(c, i)
% The index of the quote that closes the string opening at C(I).
    j = i + 1;
    while j <= numel(c) && c(j) ~= '"'
        if c(j) == '\', j = j + 1; end
        j = j + 1;
    end
end

function e = valueEnd(c, i)
% The index of the last character of the JSON value starting at or after
% C(I): the bracket that closes an array or object, or the end of a scalar.
    while isspace(c(i)), i = i + 1; end
    if c(i) == '"'
        e = stringEnd(c, i);
        return
    end
    if c(i) ~= '[' && c(i) ~= '{'
        e = i;
        while e < numel(c) && ~any(c(e+1) == ',}] ') && ~isspace(c(e+1))
            e = e + 1;
        end
        return
    end
    depth = 0; e = i;
    while e <= numel(c)
        switch c(e)
            case '"', e = stringEnd(c, e);
            case {'{', '['}, depth = depth + 1;
            case {'}', ']'}
                depth = depth - 1;
                if depth == 0, return; end
        end
        e = e + 1;
    end
end

function txt = removeMember(txt, first, last)
% TXT without the member spanning FIRST:LAST and one comma beside it: the
% one after it, else the one before.
    c = char(txt);
    after = last + 1;
    while after <= numel(c) && isspace(c(after)), after = after + 1; end
    if after <= numel(c) && c(after) == ','
        c(first:after) = [];
    else
        before = first - 1;
        while before >= 1 && isspace(c(before)), before = before - 1; end
        if before >= 1 && c(before) == ','
            c(before:last) = [];
        else
            c(first:last) = [];
        end
    end
    txt = string(c);
end

function txt = plainText(txt)
% Claude's output without the terminal escape sequences it writes, which
% show as noise in MATLAB, and other control characters but newline and tab.
    txt = regexprep(string(txt), ...
        "\x1B(\[[0-?]*[ -/]*[@-~]|\][^\x07\x1B]*(\x07|\x1B\\)|[()][0-9A-Za-z]|[0-9=><A-Za-z])", "");
    txt = regexprep(txt, "[\x00-\x08\x0B-\x1F\x7F]", "");
end
