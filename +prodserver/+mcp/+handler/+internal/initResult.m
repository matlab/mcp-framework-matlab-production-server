function [result, httpCode, httpMsg, msgHeaders, r] = initResult(jrpc)
%initResult Initialize default result state for an MCP method handler.
%   Returns a result struct with jsonrpc field set, HTTP 200 OK status,
%   empty message headers, and an empty content struct r.

% Copyright 2025-2026, The MathWorks, Inc.

    result.jsonrpc = jrpc.jsonrpc;
    httpCode = 200;
    httpMsg = 'OK';
    msgHeaders = {};
    r = struct();
end
