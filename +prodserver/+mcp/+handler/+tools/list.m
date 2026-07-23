function [result, httpCode, httpMsg, msgHeaders] = list(jrpc)
%list Handle MCP tools/list request. Returns all tool definitions from the
%   definition file as a JSON array.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants


    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    d = load(MCPConstants.DefinitionFile);
    r.tools = d.(MCPConstants.DefinitionVariable).tools;

    % Must be returned as an array in JSON. And since it's a structure,
    % we can force JSON to treat it as an array only by embedding
    % scalar structures in a cell array.
    if iscell(r.tools) == false
        r.tools = { r.tools };
    end

    result.result = r;

    % Replace dollarDefs key with $defs -- the tool description is stored
    % as a MATLAB structure, but $defs is NOT a valid MATLAB field name, so
    % the structure uses an alias, dollarDefs.
    result = strrep(jsonencode(result),MCPConstants.DefsField, ...
        MCPConstants.DefsJSON);

    msgHeaders = vertcat(msgHeaders, ...
        {MCPConstants.ContentType, char(Constants.MIMETypeJSON)});

end
