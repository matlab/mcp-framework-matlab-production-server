function [items,id] = list(endpoint, session, resource, opts)
% list Return the server's list of one or more primitive resources.

% Copyright 2025, The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        session string { mustBeTextScalar }
        resource prodserver.mcp.Primitive
        opts.timeout double { mustBePositive }
        opts.id double { mustBePositive } = 1
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField

    data.jsonrpc = MCPConstants.jrpcVersion;
    id = opts.id;
    for n = 1:numel(resource)
        data.method = lower(string(resource(n))) + "/list";
        data.id = id; id = id + 1;
        % Must send session ID with all messages post-initialization.
        headers = [
            matlab.net.http.HeaderField('Content-Type', 'application/json'), ...
            matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
            ];
        body = matlab.net.http.MessageBody(data);
        request = matlab.net.http.RequestMessage('POST', headers, body);
        response = send(request,endpoint);
        prodserver.mcp.internal.requireSuccess(response,endpoint, ...
            request=data.method);
    
        % Expect information about the primitive. 
        pfield = lower(string(resource(n)));
        if hasField(response,"Body.Data.result."+pfield) == false
        end
        items.(pfield) = response.Body.Data.result.(pfield);
    end
end