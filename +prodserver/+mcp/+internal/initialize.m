function [session,id,capabilities] = initialize(endpoint, opts)
% initialize Send initialize message to MCP server at endpoint. 

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        opts.require prodserver.mcp.Primitive { mustBeVector } = "None"
        opts.id double { mustBePositive } = 1
        opts.timeout double {mustBePositive} = 60
        opts.retry double {mustBePositive} = 30
        opts.delay double {mustBePositive} = 2
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.protocol.v20250618.Constants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.getHeaderValue

    data.jsonrpc = MCPConstants.jrpcVersion;
    data.method = "initialize";
    data.params.protocolVersion = Constants.Version;
    data.params.clientInfo.name = "MATLAB";
    data.params.clientInfo.title = "MATLAB desktop";
    data.params.clientInfo.version = "1.0.0";
    data.id = opts.id;
    id = opts.id + 1;
    
    uri = matlab.net.URI(endpoint);
    headers = prodserver.mcp.internal.mcpPostHeaders();
    body = matlab.net.http.MessageBody(data);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    
    % Send the request and receive the response
    response = prodserver.mcp.internal.sendRequest(request,uri, ...
        timeout=opts.timeout, retry=opts.retry, delay=opts.delay, ...
        label=data.method);
  
    % Server should have created a session ID
    session = getHeaderValue(Constants.SessionId, response.Header);
    if isempty(session) || strlength(session) < 1
        error("prodserver:mcp:NoSessionFromServer", ...
            "No session ID returned from initialization of server %s.", ...
            endpoint);
    end
    
    % From here on the server holds a session for us. Any failure must end
    % it before reporting, or every failed connect leaks one (ND9).
    try
        capabilities = finishHandshake(response, endpoint, uri, session, opts);
    catch ex
        try
            prodserver.mcp.internal.terminate(endpoint, session);
        catch
            % The original failure is the one worth reporting.
        end
        rethrow(ex);
    end
end


function capabilities = finishHandshake(response, endpoint, uri, session, opts)
%finishHandshake Check the required capabilities, then send
%   notifications/initialized.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.protocol.v20250618.Constants
    import prodserver.mcp.internal.hasField

    % Expect server to respond with the required capabilities.
    capabilities = [];
    if ~isempty(opts.require)
        for n = 1:numel(opts.require)
            resource = mcpName(opts.require(n));
            if hasField(response, ...
                    "Body.Data.result.capabilities."+resource) == false
            error("prodserver:mcp:NoToolsOnServer", ...
                "No %s available from Model Context Protocol " + ...
                "server %s.", resource, endpoint);
            end
        end
        capabilities = response.Body.Data.result.capabilities;
    end
    
    % Inform the server that initialize is complete on the client side.
    data=[];
    data.jsonrpc = MCPConstants.jrpcVersion;
    data.method = "notifications/initialized";
    headers = [
        prodserver.mcp.internal.mcpPostHeaders(), ...
        matlab.net.http.HeaderField(Constants.SessionId, char(session))
        ];
    body = matlab.net.http.MessageBody(data);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    % Bounded, like every other request here (XD29).
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout, ...
        ResponseTimeout=opts.timeout);
    response = send(request,uri,httpOpts);
    % Expect 200-class HTTP response, no data.
    prodserver.mcp.internal.requireSuccess(response,endpoint, ...
        request=data.method);
end


