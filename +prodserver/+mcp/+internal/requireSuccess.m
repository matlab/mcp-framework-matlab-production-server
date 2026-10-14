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

    sc = response.StatusCode;

    % A JSON-RPC error member is a failure whatever HTTP status carries it, so
    % this is checked before the status at all. Most of them arrive on a 200:
    % the client-level codes -- parse error, invalid request, method not found,
    % invalid params, resource not found -- are protocol failures, not transport
    % failures, so the transport correctly reports success. Only a genuine
    % internal fault is a 500. Gating the inspection on the status therefore
    % missed every one of them, and the caller went on to fail further down on
    % the absence of a result, reporting a missing field instead of the reason
    % the server gave for not sending one.
    %
    % The test is error.code rather than error, because a bare error field is
    % not necessarily a JSON-RPC error object: signatureHandler answers an
    % unsupported verb with struct('error', <char>), which has no code and must
    % keep falling through to the HttpError branch below.
    if hasField(response,"Body.Data.error.code")
        ex = MException("prodserver:mcp:RemoteError", ...
            "Request %s to %s generated JSON-RPC protocol " + ...
            "error: %s (code %d).", opts.request, uri, ...
            errorMessage(response.Body.Data.error), ...
            response.Body.Data.error.code);
        throwAsCaller(ex);
    end

    % A tool that ran and raised, reported through the MCP isError convention.
    % Like the error member above, this is a failure whatever status carries
    % it, and it normally arrives on a 200: the transport and the protocol both
    % worked. It used to be inspected only on a 5xx, which this server never
    % sends with isError, so every tool error passed as a success and the
    % caller either complained about missing structured content or returned
    % the error text as the tool's output. Only CallToolResult defines
    % isError, so no other method's result can trip this.
    if hasField(response,"Body.Data.result.isError") && ...
            isequal(response.Body.Data.result.isError,true)
        ex = MException("prodserver:mcp:ToolError", ...
            "Request %s to %s raised an error in the tool: %s", ...
            opts.request, uri, toolErrorText(response.Body.Data.result));
        throwAsCaller(ex);
    end

    % Check HTTP status code.
    if double(sc) >= opts.failure
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

function msg = errorMessage(err)
%errorMessage The message from a JSON-RPC error object.
%   JSON-RPC requires message alongside code, but a server that omits it must
%   not turn a reportable protocol error into an indexing failure inside the
%   reporting code -- the code alone still tells the caller what went wrong.

    if isfield(err,'message') && ~isempty(err.message)
        msg = string(err.message);
    else
        msg = "(no message)";
    end
end

function txt = toolErrorText(result)
%toolErrorText The text parts of an isError result's content, joined.
%   content is an array, which jsondecode returns as a struct array when its
%   items share fields and as a cell array when they do not. Indexing .text on
%   a struct array yields a comma-separated list, so every shape is walked
%   item by item, and non-text items are skipped.

    txt = "(no error text)";
    if ~isfield(result,'content') || isempty(result.content)
        return
    end
    items = result.content;
    if isstruct(items)
        items = num2cell(items);
    elseif ~iscell(items)
        return
    end
    parts = string.empty;
    for k = 1:numel(items)
        item = items{k};
        if isstruct(item) && isfield(item,'text') && ...
                (ischar(item.text) || isstring(item.text))
            parts(end+1) = string(item.text); %#ok<AGROW>
        end
    end
    if ~isempty(parts)
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