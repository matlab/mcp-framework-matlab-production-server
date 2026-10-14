function code = mapErrorCode(ex)
%mapErrorCode Map a MATLAB exception identifier to a JSON-RPC error code.
%   Only protocol-level exceptions reach this function (tool-execution
%   errors are reported as isError results by tools/call). Unknown
%   identifiers map to the generic internal-error code.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    id = string(ex.identifier);

    % Malformed JSON. The mcpHandler decode call site labels these
    % explicitly, but jsondecode is reachable from deeper code too, and an
    % unlabelled JSON failure is still a parse error wherever it came from.
    parseErrors = startsWith(id, "prodserver:mcp:ParseError") || ...
        startsWith(id, "MATLAB:json:");

    % Well-formed JSON that is not a well-formed JSON-RPC request: bad or
    % missing jsonrpc version, missing method, or a batch request (which
    % this server does not support).
    invalidRequests = startsWith(id, "prodserver:mcp:InvalidRequest");

    % The request named a method this server does not implement.
    methodNotFound = startsWith(id, "prodserver:mcp:UnsupportedRequest");

    % The method exists but its params are missing, incomplete, or name
    % something that does not resolve.
    invalidParams = startsWith(id, "prodserver:mcp:BadInputArguments") || ...
        startsWith(id, "prodserver:mcp:ToolUnavailable") || ...
        startsWith(id, "prodserver:mcp:AmbiguousToolName") || ...
        startsWith(id, "prodserver:mcp:AmbiguousResourceURL") || ...
        startsWith(id, "prodserver:mcp:BadResourceRead") || ...
        startsWith(id, "prodserver:mcp:MissingParams");

    % MCP-specific: resources/read named a URI this server does not host.
    resourceNotFound = startsWith(id, "prodserver:mcp:ResourceNotFound");

    if parseErrors
        code = MCPConstants.ErrorParseError;            % -32700
    elseif invalidRequests
        code = MCPConstants.ErrorInvalidRequest;        % -32600
    elseif methodNotFound
        code = MCPConstants.ErrorMethodNotFound;        % -32601
    elseif invalidParams
        code = MCPConstants.ErrorInvalidParams;         % -32602
    elseif resourceNotFound
        code = MCPConstants.ErrorResourceNotFound;      % -32002
    else
        code = MCPConstants.ErrorInternalError;         % -32603
    end
end
