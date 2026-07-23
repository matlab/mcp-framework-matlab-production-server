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

    % If the method got this far, it uses a protocol we support, so
    % just copy the request protocol into the response.
    protocolVersion = jrpc.params.protocolVersion;

    % This server supports tools and nominally emits a notification
    % when the list of tools changes, which is never.
    r.capabilities.tools.listChanged = true;

    % This server supports resources and nominally emits a notification
    % when the list of resources changes, which is also never.
    r.capabilities.resources.listChanged = true;

    % Unique session ID for state management.
    session = matlab.lang.internal.uuid;

    r.protocolVersion = protocolVersion;
    r.serverInfo.name = "MATLAB Production Server";
    if contains(protocolVersion,"2024") == false
        r.serverInfo.title = "Prototype MCP Server";
    end
    r.serverInfo.version = "1.0.0";

    % All header data must be char, not string.
    msgHeaders = vertcat(msgHeaders, ...
        { MCPConstants.SessionId char(session); ...
          MCPConstants.ProtocolVersion protocolVersion });

    result.result = r;
end
