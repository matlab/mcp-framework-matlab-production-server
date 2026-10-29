function requireSuccess(response,uri,opts)
% requireSuccess Require that an HTTP response has code lower than
% failure and that response is free of JSON-RPC errors and tool errors.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        response matlab.net.http.ResponseMessage
        uri string { prodserver.mcp.validation.mustBeURI }
        opts.failure double { mustBePositive } = 300
        opts.request string = ""
    end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants
    C = prodserver.mcp.protocol.v20260728.Constants;

    sc = response.StatusCode;

    % The body is inspected at ANY status, not only a failing one. A JSON-RPC
    % error is a failure whatever status carries it: 2025-06-18 reports an
    % unknown tool or bad arguments as -32602 over HTTP 200, and 2026-07-28
    % uses 400 and 404. Likewise result.isError: MCP reports a tool that ran
    % and failed in band, over 200, and a caller that asked for the tool's
    % outputs must get an error rather than the error text in place of them
    % (XD32). Callers that want the raw response do not call requireSuccess.
    %
    % The one exception is a non-2xx status the caller has explicitly
    % tolerated by raising opts.failure (terminate allows any 4xx): that
    % caller has said the response is acceptable whatever it carries.
    data = [];
    tolerated = double(sc) >= 300 && double(sc) < opts.failure;
    if ~isempty(response.Body) && ~tolerated
        data = response.Body.Data;
    end

    if prodserver.mcp.internal.isJsonRpcError(data)
        code = data.error.code;
        % The identifier decides whether prodserver.mcp.call and its
        % siblings clear the protocol cache and retry, because
        % isProtocolError matches "RemoteError". Only the codes that can
        % mean "you are speaking the wrong revision" may be retried. Any
        % other code is final, and -32603 in particular can be raised after
        % the tool has run (encoding its outputs), so retrying it would run
        % the tool a second time.
        if isnumeric(code) && isscalar(code) && ...
                any(code == [C.ErrorHeaderMismatch, ...
                C.ErrorUnsupportedVersion, MCPConstants.ErrorMethodNotFound])
            id = "prodserver:mcp:RemoteError";
        else
            id = "prodserver:mcp:JsonRpcError";
        end
        ex = MException(id, ...
            "Request %s to %s generated JSON-RPC protocol " + ...
            "error: %s (code %s).", opts.request, uri, ...
            string(data.error.message), string(code));
        throwAsCaller(ex);
    end

    if hasField(data, "result.isError") && ...
            (isequal(data.result.isError, true) || isequal(data.result.isError, 1))
        content = [];
        if hasField(data, "result.content")
            content = data.result.content;
        end
        % ToolError, deliberately not matching isProtocolError: the tool ran,
        % and a retry would run it again.
        ex = MException("prodserver:mcp:ToolError", ...
            "Request %s to %s generated tool error: %s", opts.request, ...
            uri, contentText(content));
        throwAsCaller(ex);
    end

    if double(sc) >= opts.failure
        % A 5xx with no JSON-RPC error gets its own identifier, ServerError,
        % because isProtocolError matches HttpError. A server that crashed,
        % or a proxy that failed, may have done so after the tool ran, and
        % prodserver.mcp.call must not answer that by sending tools/call a
        % second time. A 4xx is a verdict on the request itself (a stale
        % archive is a 404), so it stays HttpError and may still be retried.
        if double(sc) >= 500
            id = "prodserver:mcp:ServerError";
        else
            id = "prodserver:mcp:HttpError";
        end
        body = errorResponseBody(response);
        if strlength(body) > 0
            ex = MException(id,...
                "Request %s to %s failed with error code %s: %s\nBody: %s", ...
                opts.request,uri,string(sc),getReasonPhrase(sc),body);
        else
            ex = MException(id,...
                "Request %s to %s failed with error code %s: %s", ...
                opts.request,uri,string(sc),getReasonPhrase(sc));
        end
        throwAsCaller(ex);
    end
end

function txt = contentText(content)
%contentText Join the text of every text item in a result's content.
%   content decodes as a struct array when every item has the same fields,
%   and as a cell array when they differ, so both shapes are walked.
    if isstruct(content)
        content = num2cell(content);
    end
    parts = string.empty;
    if iscell(content)
        for k = 1:numel(content)
            c = content{k};
            if isstruct(c) && isscalar(c) && isfield(c, "text") && ...
                    (ischar(c.text) || isstring(c.text))
                parts(end+1) = string(c.text); %#ok<AGROW>
            end
        end
    end
    if isempty(parts)
        txt = "(no text content)";
    else
        txt = strjoin(parts, newline);
    end
end

function summary = errorResponseBody(response)
    summary = " (empty)";
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
