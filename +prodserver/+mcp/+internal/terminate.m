function terminate(endpoint, session, opts)
% terminate End a Model Context Protocol session at a given endpoint.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        endpoint string { prodserver.mcp.validation.mustBeMCPServer }
        session string { mustBeTextScalar }
        % Runs inside onCleanup when a call finishes, so it must not be able
        % to wait forever on a server that stops answering (XD29).
        opts.timeout double { mustBePositive } = 10
    end

    import prodserver.mcp.protocol.v20250618.Constants

    headers = [
        matlab.net.http.HeaderField(Constants.SessionId, char(session))
        ];
    request = matlab.net.http.RequestMessage('DELETE', headers);
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout, ...
        ResponseTimeout=opts.timeout);
    response = send(request,endpoint,httpOpts);
    % Any response except "Server Error" is OK. 400-class HTTP errors are
    % allowed, and do not represent a reportable offense.
    prodserver.mcp.internal.requireSuccess(response,endpoint,failure=500, ...
        request="delete");
end