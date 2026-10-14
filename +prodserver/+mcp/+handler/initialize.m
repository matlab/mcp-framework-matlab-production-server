function [result, httpCode, httpMsg, msgHeaders] = initialize(jrpc)
%initialize Handle MCP initialize request. Negotiates protocol version,
%   capabilities, and session ID.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    if isfield(jrpc,"params")
        if isfield(jrpc.params,"capabilities")
            % Two capabilities defined in the protocol: roots and
            % sampling. roots means the LLM can access some part of the
            % file system. sampling means the tool can make agentic
            % requests of the LLM. (mind == blown).
            %
            % Eventually we will make use of these capabilities, but
            % for now we neglect them...
            jrpc.params.capabilities;
        end
    end

    % protocolVersion is required by the initialize schema.
    if ~prodserver.mcp.internal.hasField(jrpc,"params.protocolVersion")
        error("prodserver:mcp:MissingParams", ...
            "initialize request lacks the required params.protocolVersion.");
    end

    % This server supports tools and nominally emits a notification
    % when the list of tools changes, which is never.
    r.capabilities.tools.listChanged = true;

    % This server supports resources and nominally emits a notification
    % when the list of resources changes, which is also never.
    r.capabilities.resources.listChanged = true;

    % Unique session ID for state management.
    session = matlab.lang.internal.uuid;

    % Report the version this server will actually speak, not the one the
    % client asked for. Echoing the request would have the server claim to
    % implement any revision a client named.
    r.protocolVersion = MCPConstants.protocolVersion;
    r.serverInfo.name = "MATLAB Production Server";
    r.serverInfo.title = "MATLAB Production Server";
    r.serverInfo.version = "1.0.0";

    % All header data must be char, not string.
    msgHeaders = vertcat(msgHeaders, ...
        { MCPConstants.SessionId char(session); });

    result.result = r;
end
