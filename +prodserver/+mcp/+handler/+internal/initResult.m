function [result, httpCode, httpMsg, msgHeaders, r] = initResult(~)
%initResult Initialize default result state for an MCP method handler.
%   Returns a result struct with jsonrpc field set, HTTP 200 OK status,
%   empty message headers, and an empty content struct r.

% Copyright 2025-2026 The MathWorks, Inc.

    % The server's version, not the request's: validateEnvelope has
    % already insisted they agree, and a handler reached any other way must
    % not echo whatever the request said (XD21).
    result.jsonrpc = prodserver.mcp.MCPConstants.jrpcVersion;
    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(200);
    msgHeaders = {};
    r = struct();
end
