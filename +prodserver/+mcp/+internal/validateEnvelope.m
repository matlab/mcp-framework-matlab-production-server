function validateEnvelope(jrpc)
%validateEnvelope Validate the JSON-RPC 2.0 envelope of a POSTed request.
%   Raises prodserver:mcp:InvalidRequest (-32600 / HTTP 400) when the body
%   parsed as JSON but is not a usable JSON-RPC 2.0 request object.
%
%   Runs at stage B' of the request pipeline: AFTER the notifications
%   carve-out in mcpHandler, so every message reaching here is a request
%   and must carry a non-null id. Calling this ahead of the carve-out would
%   reject every notification, which legitimately has no id.

% Copyright 2026 The MathWorks, Inc.

    if isempty(jrpc) || ~isstruct(jrpc) || ~isscalar(jrpc)
        error("prodserver:mcp:InvalidRequest", ...
            "Request body is not a JSON-RPC 2.0 request object.");
    end

    if ~isfield(jrpc, "jsonrpc") || isempty(jrpc.jsonrpc)
        error("prodserver:mcp:InvalidRequest", ...
            "Request is missing the required 'jsonrpc' member.");
    end
    if ~(ischar(jrpc.jsonrpc) || isstring(jrpc.jsonrpc)) || ...
            ~strcmp(string(jrpc.jsonrpc), prodserver.mcp.MCPConstants.jrpcVersion)
        error("prodserver:mcp:InvalidRequest", ...
            "Unsupported JSON-RPC version; 'jsonrpc' must be the string ""%s"".", ...
            prodserver.mcp.MCPConstants.jrpcVersion);
    end

    if ~isfield(jrpc, "method") || isempty(jrpc.method)
        error("prodserver:mcp:InvalidRequest", ...
            "Request is missing the required 'method' member.");
    end
    if ~(ischar(jrpc.method) || isstring(jrpc.method)) || ...
            ~isscalar(string(jrpc.method))
        error("prodserver:mcp:InvalidRequest", ...
            "Request member 'method' must be a single string.");
    end

    % A JSON-RPC request -- as opposed to a notification -- must carry an
    % id. Notifications never reach this point.
    if ~isfield(jrpc, "id") || isempty(jrpc.id)
        error("prodserver:mcp:InvalidRequest", ...
            "JSON-RPC request '%s' is missing the required 'id' member.", ...
            string(jrpc.method));
    end
end
