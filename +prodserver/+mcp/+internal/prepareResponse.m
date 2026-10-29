function response = prepareResponse(code, msg, opts)
% Prepare response from custom web handler

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        code { mustBeNumeric }
        msg char
        opts.body = []
        opts.ct char = ''
        opts.sid string = string.empty
        opts.headers cell = {};
    end


    import prodserver.mcp.MCPConstants

    % All non-body text of any kind returned in this structure MUST be
    % char, not string. Header names and values, the HTTP message,
    % everything.
    %
    % The Content-Length row is only a placeholder for encodeBody, whose
    % setHeaderValue fills an existing row and errors on a missing one. It
    % is removed again below.
    response = struct(...
        'ApiVersion',[1 0 0], ...
        'HttpCode',code, ...
        'HttpMessage',msg, ...
        'Headers', {{'Server' MCPConstants.ServerHeader; ...
        MCPConstants.ContentLength '0'; ...
        MCPConstants.ContentType opts.ct;}});

    if ~isempty(opts.headers)
        response.Headers = [response.Headers; opts.headers];
    end
    if ~isempty(opts.body)
        response.Body = opts.body;
    end 

    if ~isempty(opts.sid)
        response.Headers = [ response.Headers; ...
            {prodserver.mcp.protocol.v20250618.Constants.SessionId, char(opts.sid)} ];
    end

    response = prodserver.mcp.internal.encodeBody(response);

    % Production Server frames the body and sends its own Content-Length, so
    % the one encodeBody sets went out as a second, duplicate header (XD17).
    % encodeBody is left alone: the client shares it, and a client request
    % does need it. A Content-Type with no body describes nothing (XD27).
    names = response.Headers(:,1);
    drop = strcmpi(names, MCPConstants.ContentLength);
    if ~isfield(response, "Body") || isempty(response.Body)
        drop = drop | strcmpi(names, MCPConstants.ContentType);
    end
    response.Headers(drop,:) = [];

end