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
            % No matching URI. MCP defines a specific error code for this,
            % and it is a protocol error with a body -- not a 204, which
            % would promise no content while still carrying a result.
            error("prodserver:mcp:ResourceNotFound", ...
                "Resource '%s' not found on this MCP server.", ...
                string(jrpc.params.uri));
        end
        r.contents = {c};
    else
        error("prodserver:mcp:BadResourceRead", "Request to read " + ...
            "resource lacks the required params.uri.");
    end
    result.result = r;
end
