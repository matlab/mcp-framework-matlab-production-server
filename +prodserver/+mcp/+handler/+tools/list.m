function [result, httpCode, httpMsg, msgHeaders] = list(jrpc, ~)
%list Handle MCP tools/list request. Returns all tool definitions from the
%   definition file as a JSON array.
%
%   Takes, and ignores, the serving protocol revision -- see
%   ProtocolDispatcher.dispatch for why every handler receives it.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    d = prodserver.mcp.handler.toolServices;
    r.tools = d.(MCPConstants.DefinitionVariable).tools;

    % Must be returned as an array in JSON. And since it's a structure,
    % we can force JSON to treat it as an array only by embedding
    % scalar structures in a cell array.
    if iscell(r.tools) == false
        r.tools = { r.tools };
    end

    result.result = r;

end
