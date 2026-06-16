function response = prepareResponse(code, msg, opts)
% Prepare response from custom web handler

% Copyright 2025, The MathWorks, Inc.

    arguments
        code { mustBeNumeric }
        msg char
        opts.body = []
        opts.ct char = ''
        opts.sid string = string.empty
    end


    % All non-body text of any kind returned in this structure MUST be
    % char, not string. Header names and values, the HTTP message,
    % everything. 
    response = struct(...
        'ApiVersion',[1 0 0], ...
        'HttpCode',code, ...
        'HttpMessage',msg, ...
        'Headers', {{'Server' 'MATLAB Production Server/Model Context Protocol (v1.0)'; ...
        'Content-Length' numel(opts.body); ...
        'Content-Type' opts.ct;}});

    if ~isempty(opts.body)
        response.Body = opts.body;
    end 

    if ~isempty(opts.sid)
        response.Headers = [ response.Headers; ...
            {prodserver.mcp.MCPConstants.SessionId, char(opts.sid)} ];
    end

    response = prodserver.mcp.internal.encodeBody(response);
end