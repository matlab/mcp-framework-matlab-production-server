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
            dd = load(MCPConstants.DefinitionFile);
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
