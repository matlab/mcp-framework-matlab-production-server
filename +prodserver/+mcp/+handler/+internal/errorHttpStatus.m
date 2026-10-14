function [httpCode, httpMsg] = errorHttpStatus(code)
%errorHttpStatus HTTP status for a JSON-RPC error code.
%   Protocol- and client-level JSON-RPC errors (parse, invalid request,
%   method not found, invalid params, resource not found) are delivered over
%   HTTP 200: the transport succeeded and the error is carried in the
%   JSON-RPC body. Only a genuine internal/server error maps to HTTP 500.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    clientErrors = [ ...
        MCPConstants.ErrorParseError, ...
        MCPConstants.ErrorInvalidRequest, ...
        MCPConstants.ErrorMethodNotFound, ...
        MCPConstants.ErrorInvalidParams, ...
        MCPConstants.ErrorResourceNotFound];

    if ismember(code, clientErrors)
        httpCode = 200;
        httpMsg = 'OK';
    else
        httpCode = 500;
        httpMsg = 'Internal Server Error';
    end
end
