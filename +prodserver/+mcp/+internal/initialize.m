function [session,id,capabilities] = initialize(endpoint, opts)

% Copyright 2025, The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        opts.require prodserver.mcp.Primitive { mustBeVector } = "None"
        opts.id double { mustBePositive } = 1
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.getHeaderValue

    data.jsonrpc = MCPConstants.jrpcVersion;
    data.method = "initialize";
    data.params.protocolVersion = MCPConstants.protocolVersion;
    data.params.clientInfo.name = "MATLAB";
    data.params.clientInfo.title = "MATLAB desktop";
    data.params.clientInfo.version = "1.0.0";
    data.id = opts.id;
    id = opts.id + 1;
    
    uri = matlab.net.URI(endpoint);
    headers = [
        matlab.net.http.HeaderField('Content-Type', 'application/json')
        ];
    body = matlab.net.http.MessageBody(data);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    
    % Send the request and receive the response
    response = request.send(uri);
    prodserver.mcp.internal.requireSuccess(response,endpoint, ...
        request=data.method); 

    % Server should have created a session ID
    session = getHeaderValue(MCPConstants.SessionId, response.Header);
    if isempty(session) || strlength(session) < 1
        error("prodserver:mcp:NoSessionFromServer", ...
            "No session ID returned from initialization of server %s.", ...
            endpoint);
    end
    
    % Expect server to respond with the required capabilities.
    capabilities = [];
    if ~isempty(opts.require)
        for n = 1:numel(opts.require)
            resource = lower(string(opts.require(n)));
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
        matlab.net.http.HeaderField('Content-Type', 'application/json'), ...
        matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
        ];
    body = matlab.net.http.MessageBody(data);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    response = send(request,uri);
    % Expect 200-class HTTP response, no data.
    prodserver.mcp.internal.requireSuccess(response,endpoint, ...
        request=data.method);
end


