function data = decodeBody(msg, opts)
%decodeBody Decode the msg.Body -- the Data or Payload field according to
%the Content-Type of the message.
%
% The message may take one of three forms: matlab.net.http.ResponseMessage,
% matlab.net.http.RequestMessage or a MATLAB Production Server custom web
% handler message structure. The only difference that matters here is that
% the first two have a "Header" field, while the third has a "Headers"
% field.
%
% decodeBody(msg, strict=true) additionally enforces the JSON-RPC request
% rules: an absent, empty or whitespace-only body raises InvalidRequest
% (whatever its Content-Type), an unparseable JSON
% body raises ParseError, and an unsupported media type raises
% UnsupportedMediaType (HTTP 415). Strict mode is for the server's POST
% request path only. It is off by default because the same function decodes
% HTTP *responses* on the client side and arbitrary bodies for
% signatureHandler, both of which rely on an unrecognized Content-Type
% falling through and returning the raw payload.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        msg
        opts.strict (1,1) logical = false
    end

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.MCPConstants

    if hasField(msg,"Body.Payload") && ~isempty(msg.Body.Payload)
        data = msg.Body.Payload;
        mps = false;
    elseif hasField(msg,"Body.Data")
        data = msg.Body.Data;
        mps = false;
    elseif hasField(msg,"Body")
        data = msg.Body;
        mps = true;
    else
        data = [];
    end

    % A body of nothing but whitespace is as empty as no body at all, and
    % must get the same -32600. Left alone it reached jsondecode and came
    % back -32700, and without a Content-Type it was a 415 -- three answers
    % for one mistake. Strict mode only: the permissive callers have never
    % treated whitespace specially and nothing asks them to.
    if opts.strict && isBlank(data)
        data = [];
    end

    if ~isempty(data)
        bodyCT = string.empty;
        if hasField(msg,"Headers")
            bodyCT = prodserver.mcp.internal.getHeaderValue(...
                MCPConstants.ContentType,msg.Headers);
        elseif hasField(msg,"Header") && ~isempty(msg.Header)
            % Through getHeaderValue, like the Headers branch, so the lookup
            % is case-insensitive here too: header names are (RFC 9110
            % §5.1), and a server answering "content-type" is conformant.
            % Built as an Nx2 list because Header may be HeaderField objects
            % or plain Name/Value structs.
            bodyCT = prodserver.mcp.internal.getHeaderValue( ...
                MCPConstants.ContentType, ...
                [{msg.Header.Name}; {msg.Header.Value}]');
        end

        % Normalize before dispatching. RFC 9110 makes parameters part of a
        % legal Content-Type, so "application/json; charset=utf-8" is a
        % conformant JSON body and must take the JSON branch. Media types
        % and subtypes are case-insensitive. This normalization MUST precede
        % any rejection branch below: without it, strict mode would reject
        % well-formed requests from conformant clients.
        bodyCT = prodserver.mcp.internal.mediaType(bodyCT);

        if bodyCT == prodserver.mcp.internal.Constants.MIMETypeJSON
            if mps
                data = native2unicode(data,"UTF-8");
            end
            if opts.strict
                text = data;
                try
                    data = jsondecode(data);
                catch parseErr
                    error("prodserver:mcp:ParseError", ...
                        "Request body is not valid JSON: %s", ...
                        parseErr.message);
                end
                % A JSON array is a JSON-RPC batch, which neither revision
                % supports (ND13). It must be caught on the text: jsondecode
                % turns a one-element array into the same scalar struct as
                % the bare object, so nothing downstream can tell them
                % apart, and the first element was answered as a single
                % request.
                if isJsonArray(text)
                    error("prodserver:mcp:InvalidRequest", ...
                        "Request body is a JSON array; JSON-RPC batches " + ...
                        "are not supported.");
                end
            else
                data = jsondecode(data);
            end
        elseif opts.strict
            % Nothing is malformed -- we simply do not speak this media
            % type. 415 is HTTP's purpose-built status. Neither MCP spec
            % addresses it, so this is an engineering choice.
            %
            % This branch must precede the octet-stream and text/* branches
            % below, not follow them. Those two exist for the permissive
            % callers -- signatureHandler and client-side response decoding
            % -- and neither is a legal carrier for a JSON-RPC request. Were
            % they tried first, a POST declaring text/plain would be accepted
            % and handed on as a char array, surfacing later as a confusing
            % -32600 instead of the 415 that actually describes the problem.
            if isempty(bodyCT)
                error("prodserver:mcp:UnsupportedMediaType", ...
                    "Request has a body but no Content-Type header; " + ...
                    "expected '%s'.", prodserver.mcp.internal.Constants.MIMETypeJSON);
            else
                error("prodserver:mcp:UnsupportedMediaType", ...
                    "Unsupported Content-Type '%s'; expected '%s'.", ...
                    bodyCT, prodserver.mcp.internal.Constants.MIMETypeJSON);
            end
        elseif bodyCT == "application/octet-stream"
            data = getArrayFromByteStream(data);
        elseif startsWith(bodyCT,"text/")
            data = native2unicode(data,"UTF-8");
        end
    else
        if opts.strict
            % Empty is not a parse failure: nothing is malformed because
            % nothing is present. -32600 ("not a valid Request object")
            % describes it precisely.
            error("prodserver:mcp:InvalidRequest", ...
                "Request body is empty; expected a JSON-RPC 2.0 request.");
        end
        data = struct.empty;
    end
end

function tf = isBlank(data)
%isBlank True if DATA, a body as received, is nothing but JSON whitespace.
%   RFC 8259 §2: space, horizontal tab, line feed, carriage return. Checked
%   on the raw bytes or characters, so the body is not decoded to find out.
    if isnumeric(data) || ischar(data)
        tf = all(ismember(data, [32 9 10 13]), "all");
    else
        tf = false;
    end
end

function tf = isJsonArray(text)
%isJsonArray True if TEXT, a JSON document, is an array at top level.
    if isnumeric(text)
        text = native2unicode(reshape(text, 1, []), "UTF-8");
    end
    tf = startsWith(strip(string(text)), "[");
end
