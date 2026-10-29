function sig = signature(tool, endpoint, client, opts)
%signature Retrieve signature data for the tool from the server.

% Copyright 2026 The MathWorks, Inc.

    arguments
        tool string
        endpoint string { prodserver.mcp.validation.mustBeURI }
        client prodserver.mcp.client.Adapter
        opts.timeout double { mustBePositive } = 10
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.ParameterKind

    headers = [
 matlab.net.http.HeaderField(MCPConstants.ContentType, 'text/plain'), ...
 client.protocolHeaders()
        ];
    body = matlab.net.http.MessageBody(tool);
    request = matlab.net.http.RequestMessage('POST', headers, body);
    handler = "signature";
    % A response timeout as well as a connect timeout: a server that
    % accepts the connection and never answers would otherwise hang the
    % call forever (XD29).
    httpOpts = matlab.net.http.HTTPOptions(ConnectTimeout=opts.timeout, ...
        ResponseTimeout=opts.timeout);
    response = send(request,endpoint,httpOpts);
    prodserver.mcp.internal.requireSuccess(response,endpoint, ...
        request=handler);
    sig = response.Body.Data;

    % Restore fields from their JSON types to the expected MATLAB types.
    % Every member is optional: a deployed archive omits 'input' for a tool
    % with no inputs and 'output' for one with no outputs (ND12, XD31).
    tool = string(fieldnames(sig)');
    io = ["input", "output"];
    for t = tool
        for i = io
            if ~hasField(sig, t + "." + i)
                continue
            end
            for f = ["name", "type", "order"]
                if isfield(sig.(t).(i), f)
                    sig.(t).(i).(f) = string(sig.(t).(i).(f));
                end
            end
            if isfield(sig.(t).(i), "kind")
                k = sig.(t).(i).kind;
                if isempty(k)
                    sig.(t).(i).kind = ParameterKind.empty;
                else
                    sig.(t).(i).kind = ParameterKind(k);
                end
            end
        end
    end
end
