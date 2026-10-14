function [result, httpCode, httpMsg, msgHeaders, r] = initResult(~)
%initResult Initialize default result state for an MCP method handler.
%   Returns a result struct with jsonrpc field set, HTTP 200 OK status,
%   empty message headers, and an empty content struct r.

% Copyright 2025-2026 The MathWorks, Inc.

    % The response version is the server's to state. Echoing the request's
    % jsonrpc field would let a client dictate it; validateEnvelope has
    % already rejected anything that is not 2.0 by the time a handler runs.
    result.jsonrpc = prodserver.mcp.MCPConstants.jrpcVersion;
    httpCode = 200;
    httpMsg = 'OK';
    msgHeaders = {};
    r = struct();
end
