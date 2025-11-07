function requireSuccess(response,uri,opts)
% requireSuccess Require that an HTTP response has code lower than
% failure and that response is free of JSON-RPC errors.

% Copyright 2025, The MathWorks, Inc.

    arguments
        response matlab.net.http.ResponseMessage
        uri string { prodserver.mcp.validation.mustBeURI }
        opts.failure double { mustBePositive } = 300
        opts.request string = ""
    end

    import prodserver.mcp.internal.hasField
    
    % Check HTTP status code -- if it's 500, check for a MATLAB error
    % message, which is often more informative.

    sc = response.StatusCode;
 
    if double(sc) >= opts.failure
        if double(sc) >= 500
            % Check JSON-RPC protocol
            if hasField(response,"Body.Data.error")
                ex = MException("prodserver:mcp:RemoteError", ...
                    "Request %s to %s generated JSON-RPC protocol " + ...
                    "error: %s (code %d).", opts.request, uri, ...
                    response.Body.Data.error.message, ...
                    response.Body.Data.error.code);
                throwAsCaller(ex);
            end
        end

        ex = MException("prodserver:mcp:HttpError",...
            "Request %s to %s failed with error code %s: %s", ...
            opts.request,uri,string(sc),getReasonPhrase(sc));
        throwAsCaller(ex);
    end
end