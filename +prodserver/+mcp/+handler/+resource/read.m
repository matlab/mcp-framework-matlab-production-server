function [result, httpCode, httpMsg, msgHeaders] = read(jrpc, ~)
%read Handle MCP resources/read request. Returns the contents of the
%   resource matching the requested URI (text or blob depending on MIME type).
%
%   Takes, and ignores, the serving protocol revision -- see
%   ProtocolDispatcher.dispatch for why every handler receives it.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    if prodserver.mcp.internal.hasField(jrpc, "params.uri")
        c = prodserver.mcp.handler.resource.contents(jrpc.params.uri);
        if isempty(c)
            % No matching URI. A missing resource is a JSON-RPC error, not a
            % silent empty success: the adapter maps it to the protocol's
            % resource-not-found code (-32002 for 2025-06-18, -32602 for
            % 2026-07-28).
            error("prodserver:mcp:ResourceNotFound", ...
                "No resource matching URI '%s'.", jrpc.params.uri);
        else
            r.contents = {c};
        end
    else
        error("prodserver:mcp:BadResourceRead", "Request to read " + ...
            "resource lacks URL.");
    end
    result.result = r;
end
