function requireSuccess(response,uri,opts)
% requireSuccess Require that an HTTP response has code lower than
% failure and that response is free of JSON-RPC errors.

% Copyright 2025-2026 The MathWorks, Inc.

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
            elseif hasField(response,"Body.Data.result.isError") && ...
                response.Body.Data.result.isError == 1
                ex = MException("prodserver:mcp:RemoteError", ...
                    "Request %s to %s generated error: %s", opts.request, ...
                    uri, response.Body.Data.result.content.text);
                throwAsCaller(ex);
            end
        end

        body = errorResponseBody(response);
        if strlength(body) > 0
            ex = MException("prodserver:mcp:HttpError",...
                "Request %s to %s failed with error code %s: %s\nBody: %s", ...
                opts.request,uri,string(sc),getReasonPhrase(sc),body);
        else
            ex = MException("prodserver:mcp:HttpError",...
                "Request %s to %s failed with error code %s: %s", ...
                opts.request,uri,string(sc),getReasonPhrase(sc));
        end
        throwAsCaller(ex);
    end
end

function summary = errorResponseBody(response)
    summary = "";
    if isempty(response.Body) || isempty(response.Body.Data)
        return
    end
    data = response.Body.Data;
    if isstruct(data)
        encoded = string(jsonencode(data));
        if strlength(encoded) <= 80
            summary = encoded;
        else
            summary = "JSON object with fields: " + ...
                strjoin(string(fieldnames(data)), ", ");
        end
    elseif ischar(data) || isstring(data)
        txt = string(data);
        if strlength(txt) <= 80
            summary = txt;
        else
            summary = extractBefore(txt, 78) + "...";
        end
    elseif isa(data, 'uint8')
        summary = sprintf("binary data (%d bytes)", numel(data));
    else
        summary = sprintf("%s value", class(data));
    end
end