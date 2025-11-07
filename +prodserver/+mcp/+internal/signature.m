function sig = signature(tool,endpoint,session,opts)

    arguments
        tool string
        endpoint string { prodserver.mcp.validation.mustBeURI }
        session string { mustBeTextScalar }
        opts.timeout double { mustBePositive } = 10
    end
    
    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    
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
end
