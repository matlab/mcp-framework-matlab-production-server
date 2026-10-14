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


    % All non-body text of any kind returned in this structure MUST be
    % char, not string. Header names and values, the HTTP message,
    % everything. 
    response = struct(...
        'ApiVersion',[1 0 0], ...
        'HttpCode',code, ...
        'HttpMessage',msg, ...
        'Headers', {{'Server' char(prodserver.mcp.internal.Constants.ServerHeader); ...
        'Content-Length' '0'; ...
        'Content-Type' opts.ct;}});

    if ~isempty(opts.headers)
        response.Headers = [response.Headers; opts.headers];
    end
    if ~isempty(opts.body)
        response.Body = opts.body;
    end 

    if ~isempty(opts.sid)
        response.Headers = [ response.Headers; ...
            {prodserver.mcp.MCPConstants.SessionId, char(opts.sid)} ];
    end

    % encodeBody sets Content-Length from the bytes it just encoded, and it is
    % right about the number -- but the number was never the problem. MPS frames
    % the response itself, so the header reaches the client twice. Measured on
    % R2026b: GET /<archive>/ping returns "Content-Length: 4" twice and
    % GET /<archive>/signature returns "Content-Length: 1760" twice, MPS's copy
    % ahead of Content-Type and this one after it. MathWorks' own custom-web-
    % handler examples never set it and still show it in their cURL output,
    % which is the documented confirmation that framing is the server's job.
    %
    % The seeded 'Content-Length' '0' row above has to stay: setHeaderValue
    % raises AmbiguousHeaderName unless the name it is asked to set already
    % exists, so removing the seed would make encodeBody throw. The length is
    % dropped after encoding instead, once the body is settled.
    response = prodserver.mcp.internal.encodeBody(response);
    keep = ~strcmpi(string(response.Headers(:,1)), ...
        string(prodserver.mcp.MCPConstants.ContentLength));
    response.Headers = response.Headers(keep,:);

end