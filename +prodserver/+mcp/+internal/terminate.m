function terminate(endpoint, session)
% terminate End a Model Context Protocol session at a given endpoint.

% Copyright 2025, The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        session string { mustBeTextScalar }
    end

    import prodserver.mcp.MCPConstants

    headers = [
        matlab.net.http.HeaderField(MCPConstants.SessionId, char(session))
        ];
    request = matlab.net.http.RequestMessage('DELETE', headers);
    response = send(request,endpoint);
    % Any response except "Server Error" is OK. 400-class HTTP errors are
    % allowed, and do not represent a reportable offense.
    prodserver.mcp.internal.requireSuccess(response,endpoint,failure=500, ...
        request="delete");
end