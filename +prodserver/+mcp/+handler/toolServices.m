function td = toolServices(opts)
%toolDefinition Return services defined by all tools on this server.

% Copyright 2026 The MathWorks, Inc.

    arguments
        opts.action string { mustBeMember(opts.action, ["get","clear"]) } = "get";
    end

    import prodserver.mcp.MCPConstants

    td = [];

    % Qualify the generic key name with the name of the current archive.
    % appdata is shared among all CTFs loaded into a single worker. Using
    % CTF root works well for deployed archives, but the root is non-unique
    % in tests running in MATLAB, so tests must more aggressively clean up
    % the services cache themselves.
    [~, archive, ~] = fileparts(ctfroot);
    serviceKey = MCPConstants.ServiceVariable + "_" + archive;

    % Don't create the variable if we're supposed to be clearing it.
    if isappdata(0,serviceKey) == false
        if strcmpi(opts.action,"get")
            dd = loadDefinition(archive);
            % Cache only after a successful load, so a failure is retried
            % on the next request instead of being served from appdata.
            setappdata(0,serviceKey, dd);
            td = dd;
        end
    else
        switch opts.action
            case "get"
                td = getappdata(0,serviceKey);
            case "clear"
                % Clear the service variable and return empty
                rmappdata(0, serviceKey);
        end
    end
end

function dd = loadDefinition(archive)
%loadDefinition Load the definition file, naming the cause of a failure.
%   A raw load error doesn't tell the operator what to do. The most likely
%   cause on a running server is a class definition clash between archives
%   in one worker, which only restarting the server in multi-MCOS mode
%   cures, so that case says so. Either way the original error is kept as
%   the cause, for the server log.
    import prodserver.mcp.MCPConstants
    try
        dd = load(MCPConstants.DefinitionFile);
    catch loadErr
        if prodserver.mcp.handler.internal.isClassSystemError(loadErr)
            err = MException("prodserver:mcp:NeedMultiMCOSMode", ...
                "Unable to load the tool definitions for archive " + ...
                "'%s': another archive in the same worker may have loaded " + ...
                "a different copy of a framework class. Set " + ...
                "environment variable %s to ""true"" on the " + ...
                "server machine and restart the server.", ...
                archive, prodserver.mcp.internal.Constants.MultiMCOSEnvVar);
        else
            err = MException("prodserver:mcp:DefinitionLoadFailed", ...
                "Unable to load the tool definitions for archive '%s' " + ...
                "from %s: %s", archive, MCPConstants.DefinitionFile, ...
                loadErr.message);
        end
        throw(addCause(err, loadErr));
    end
end
