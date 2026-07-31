function [result, httpCode, httpMsg, msgHeaders] = ping(jrpc)
%ping Handle MCP ping request. Returns an empty result with the request id.

% Copyright 2025-2026 The MathWorks, Inc.

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;
    result.result = r;
end
