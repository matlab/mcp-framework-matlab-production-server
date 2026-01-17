function sig = signature(tool,endpoint,session,opts)
%signature Retrieve signature data for the tool from the server.

% Copyright 2026, The MathWorks, Inc.

    arguments
        tool string
        endpoint string { prodserver.mcp.validation.mustBeURI }
        session string { mustBeTextScalar }
        opts.timeout double { mustBePositive } = 10
    end
    
    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.ParameterKind
    
    % Must send session ID with all messages post-initialization.
    headers = [
 matlab.net.http.HeaderField(MCPConstants.ContentType, 'text/plain'), ...
 matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
        ];
    body = matlab.net.http.MessageBody(tool);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    handler = "signature";
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout);
    response = send(request,endpoint,httpOpts);
    prodserver.mcp.internal.requireSuccess(response,endpoint, ...
        request=handler);
    sig = response.Body.Data;

    % Restore fields from their JSON types to the expected MATLAB types.
    tool = string(fieldnames(sig)');
    io = ["input", "output"];
    for t = tool
        for i = io
            sig.(t).(i).name = string(sig.(t).(i).name);
            sig.(t).(i).type = string(sig.(t).(i).type);
            sig.(t).(i).order = string(sig.(t).(i).order);
            k = sig.(t).(i).kind;
            if isempty(k)
                sig.(t).(i).kind = ParameterKind.empty;
            else
                sig.(t).(i).kind = ParameterKind(k);
            end
        end
    end
end
