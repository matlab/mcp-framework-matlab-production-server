function [result, httpCode, httpMsg, msgHeaders] = read(jrpc)
%read Handle MCP resources/read request. Returns the contents of the
%   resource matching the requested URI (text or blob depending on MIME type).

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    if isfield(jrpc,"params") && isfield(jrpc.params,"uri")
        c = prodserver.mcp.handler.resource.contents(jrpc.params.uri);
        if isempty(c)
            % No matching URI.
            httpCode = 204;
            httpMsg = 'No Content';
        else
            r.contents = {c};
        end
    else
        error("prodserver:mcp:BadResourceRead", "Request to read " + ...
            "resource lacks URL.");
    end
    result.result = r;
end
