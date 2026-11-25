function [result, httpCode, httpMsg, msgHeaders] = list(jrpc, ctx)
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

    % uri2json is for an MCP App's view, which only a client that supports
    % MCP Apps has: no other client is offered it. tools/call refuses it to
    % them too.
    if ~supports(ctx.Capabilities, MCPConstants.UIExtension_JSON)
        app = cellfun(@(t) string(t.name) == MCPConstants.Uri2JsonTool, r.tools);
        r.tools = r.tools(~app);
    end

    result.result = r;

end
