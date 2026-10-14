function jrpc = validateEnvelope(jrpc)
%validateEnvelope Verify a decoded request is a well-formed JSON-RPC 2.0 call.
%
%   JRPC = validateEnvelope(JRPC) raises prodserver:mcp:InvalidRequest when
%   the decoded JRPC is not a single JSON-RPC 2.0 request: a batch, a bare
%   JSON value that is not an object, a missing or wrong jsonrpc version, or
%   a missing method. On success it returns JRPC with an explicit null id
%   normalized to NaN. Params are NOT checked here -- which params are
%   required depends on the method, so each handler validates its own.
%
%   It never raises a parse error. JRPC was decoded, so it is valid JSON; an
%   empty or undecodable body is the caller's -32700 to report.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    % A JSON array of requests -- a batch -- decodes two different ways.
    % Members with differing field sets (a request mixed with a notification,
    % which is the common real case) give a cell array; members with
    % identical field sets give a non-scalar struct array. A batch of one
    % decodes to a scalar struct, indistinguishable from a bare request, so
    % mcpHandler wraps it in a cell from the raw body. Either way this
    % server handles exactly one request per HTTP POST.
    if iscell(jrpc)
        error("prodserver:mcp:InvalidRequest", ...
            "Batch requests are not supported. Send a single JSON-RPC " + ...
            "request per HTTP POST.");
    end

    % A bare number, string, boolean or null is valid JSON but not a request
    % object. JSON-RPC 2.0 calls that an invalid request, not a parse error.
    if ~isstruct(jrpc)
        error("prodserver:mcp:InvalidRequest", ...
            "Request must be a JSON object, not a bare JSON value.");
    end

    if ~isscalar(jrpc)
        error("prodserver:mcp:InvalidRequest", ...
            "Batch requests are not supported. Send a single JSON-RPC " + ...
            "request per HTTP POST.");
    end

    if ~isfield(jrpc,"jsonrpc")
        error("prodserver:mcp:InvalidRequest", ...
            "Request is missing the required 'jsonrpc' member.");
    end

    if ~isequal(string(jrpc.jsonrpc), MCPConstants.jrpcVersion)
        error("prodserver:mcp:InvalidRequest", ...
            "Unsupported JSON-RPC version '%s'. This server speaks %s.", ...
            string(jrpc.jsonrpc), MCPConstants.jrpcVersion);
    end

    if ~isfield(jrpc,"method")
        error("prodserver:mcp:InvalidRequest", ...
            "Request is missing the required 'method' member.");
    end

    if ~(ischar(jrpc.method) || isstring(jrpc.method)) || ...
            ~isscalar(string(jrpc.method)) || ...
            strlength(string(jrpc.method)) == 0
        error("prodserver:mcp:InvalidRequest", ...
            "Request 'method' must be a non-empty string.");
    end

    % jsondecode turns an explicit "id": null into an empty double, and
    % isfield still reports it present. That is a request with a null id, not
    % a notification -- but every handler assigns result.id = jrpc.id, and an
    % empty id would re-encode as "id":[], which is not valid JSON-RPC.
    % Normalize to NaN, which jsonencode writes back as null.
    if isfield(jrpc,"id") && isempty(jrpc.id)
        jrpc.id = NaN;
    end
end
