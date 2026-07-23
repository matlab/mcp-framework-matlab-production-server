function [result, httpCode, httpMsg, msgHeaders] = listFallback(jrpc)
%listFallback Handle unrecognized MCP *\/list requests.
%   Returns 204 No Content for any /list method not handled by a more
%   specific handler.

% Copyright 2025-2026 The MathWorks, Inc.

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;
    httpCode = 204;
    httpMsg = 'No Content';
    result.result = r;
end
