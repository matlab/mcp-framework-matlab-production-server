function response = mcpHandler(request)
%mcpHandler Custom web handler for MCP JSON RPC protocol.
%
%   The request pipeline is ordered deliberately:
%
%     1. SSE endpoint    -- any request for the legacy HTTP+SSE path is 404.
%                           This server has no streaming transport, so that
%                           endpoint is not a resource it hosts.
%     2. HTTP verb       -- anything but POST or DELETE is 405, with an Allow
%                           header. Ahead of path parsing and metrics, so the
%                           GET -> 405 signal that tells clients this server
%                           has no server-to-client SSE stream cannot be
%                           masked by a later 400 or by a failure to parse the
%                           archive name out of the URL.
%     3. Accept          -- a POST that will accept only an event stream is
%                           406: there is no representation to send it.
%     4. Content-Type    -- a POST whose body is declared as anything but
%                           application/json is 415. An absent header is
%                           permitted; case and parameters are ignored.
%     5. Protocol version-- an MCP-Protocol-Version header naming a version
%                           this server does not implement is 400. An absent
%                           header is permitted.
%     6. DELETE          -- session termination: 204, or 400 with no session.
%     7. POST decode     -- an empty body, or one that is not JSON, is a
%                           -32700 parse error.
%     8. Envelope check  -- not a single well-formed JSON-RPC 2.0 request is
%                           a -32600 invalid request.
%     9. Session         -- a non-initialize request with no session is 400.
%    10. Dispatch        -- unknown methods are -32601.
%
%   Steps 1-6 and 9 are transport-level refusals: they carry an HTTP error
%   status and no body. Steps 7, 8 and 10 are protocol-level errors: HTTP 200
%   with the error in a JSON-RPC body (except a genuine internal fault, which
%   is 500). A notification -- a request with no id -- always gets 202 and an
%   empty body, whatever happens while handling it.
%
%   Notifications are exempt from the session gate in step 9. JSON-RPC forbids
%   replying to a request with no id, so there is nobody to send a 400 to, and
%   several clients send notifications/initialized before they have stored the
%   session id from the initialize response.
%
%   A response that carries no body carries no Content-Type either: there is
%   nothing to describe. It carries no Content-Length from here either, even
%   though a client does need one to tell an empty body from an unfinished one
%   -- MPS supplies it, measured on R2026b as Content-Length: 0 on every
%   bodiless response this handler returns. Stating it here as well put the
%   header on the wire twice.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants
    import prodserver.mcp.internal.getHeaderValue

    % Every response field is initialized up front. The previous version
    % assigned httpCode only inside the switch arms it knew about, so an
    % unsupported verb reached the response assembly with it undefined and
    % took the handler down.
    httpCode = 500;
    httpMsg = 'Internal Server Error';
    msgHeaders = {};
    headers = {};
    data = [];
    jrpc = [];
    isNotification = false;

    % Version to report back. Set only on paths that were not refused: there
    % is nothing to report about a request we declined to process.
    replyVersion = string.empty;

    % The legacy HTTP+SSE transport is not implemented, and the /sse endpoint
    % it is built around does not exist here. The path is routed to this
    % handler (see instance_routes.json) only so that the refusal is clean and
    % attributable instead of whatever the server emits for an unrouted path.
    %
    % 404 rather than 405: the resource is absent, so there is no honest list
    % of methods to put in an Allow header. The MCP backwards-compatibility
    % rules name 404 and 405 interchangeably as the signal that the deprecated
    % transport is unavailable, so no client loses the ability to detect it.
    %
    % This runs before the verb gate because the path refusal is the more
    % specific and more useful answer: "that endpoint is not here" beats
    % "wrong method on an endpoint that is".
    if endsWith(string(request.Path), MCPConstants.SSE, IgnoreCase=true)
        response = refusal(404, 'Not Found');
        return
    end

    % Verb gate, ahead of path parsing and metrics. Path parsing below can
    % itself fail, and that failure must not turn a GET -- whose 405 is how
    % clients discover this server opens no server-to-client stream -- into a
    % 500.
    verb = lower(string(request.Method));
    if ~ismember(verb, ["post" "delete"])
        % RFC 9110 requires Allow on a 405, and CORS preflight depends on it.
        response = refusal(405, 'Method Not Allowed', ...
            {'Allow' 'POST, DELETE'});
        return
    end

    % Content negotiation. The spec has clients list both application/json and
    % text/event-stream on a POST, leaving the server free to answer with
    % either; this server always answers with JSON. A client that asks only
    % for an event stream is asking for the one representation there is no way
    % to produce, and 406 says exactly that. Sending it JSON it said it would
    % not accept, or an empty 200, would both be worse.
    %
    % An absent Accept header is permitted and means */*.
    if verb == "post" && demandsEventStream( ...
            getHeaderValue('Accept', request.Headers))
        response = refusal(406, 'Not Acceptable');
        return
    end

    % The request body must be JSON. A POST that declares any other type --
    % including application/x-www-form-urlencoded, which is what curl -d sends
    % unless told otherwise -- is refused here rather than handed to the
    % decoder, which would leave it undecoded and report a -32700 parse error
    % for a body that was never offered as JSON. An absent Content-Type is
    % permitted and means JSON; parameters such as charset, and the case of
    % the type, do not matter.
    if verb == "post" && isUnsupportedMediaType( ...
            getHeaderValue(MCPConstants.ContentType, request.Headers))
        response = refusal(415, 'Unsupported Media Type');
        return
    end

    try
        % Need server name for metrics. Expecting URLs to look like this:
        %   /<server>/mcp
        % Trying to extract <server> from that string. Since split will add
        % "" for /, <server> should the the 2nd element in the return
        % value from split.
        serverName = split(request.Path,Constants.URISep);
        if numel(serverName) >= 2
            serverName = serverName(2);
        else
            serverName = "";
        end
        if isempty(serverName) || strlength(serverName) == 0
            error("prodserver:mcp:InvalidServerURL", ...
                "Cannot determine server name from request URL '%s'.", ...
                request.Path);
        end

        % Record elapsed time -- this time measures overhead and tool
        % call time.
        serverTimeMetric = MCPConstants.MCPMetricPrefix + serverName + "_ElapsedTime";
        et = tic();
        elapsed = onCleanup(@()prodserver.metrics.incrementCounter(serverTimeMetric,toc(et))); %#ok<NASGU>

        session = getHeaderValue(MCPConstants.SessionId, request.Headers);
        if ~isBlank(session)
            headers = {MCPConstants.SessionId session};
        end

        protocolVersion = getHeaderValue(MCPConstants.ProtocolVersion, ...
            request.Headers);

        % Count the number of times mcpHandler is called.
        prodserver.metrics.incrementCounter(MCPConstants.MCPRequestMetric,1);

        % Record number of calls
        serverMetric = MCPConstants.MCPMetricPrefix + serverName + "_Request";
        prodserver.metrics.incrementCounter(serverMetric,1)

        if isUnsupportedVersion(protocolVersion)
            % Client asked for a protocol revision this server does not
            % implement. A transport-level refusal, so no JSON-RPC body.
            httpCode = 400;
            httpMsg = 'Bad Request';

        elseif verb == "delete"
            % A session-termination DELETE carries no JSON-RPC body; it is
            % identified by the Mcp-Session-Id request header. With no
            % session the request cannot be attributed to one, which is the
            % same missing-session failure as any other non-initialize
            % request. The session id, when present, is already echoed
            % through `headers` above, so nothing is added here -- that
            % would duplicate Mcp-Session-Id.
            if isBlank(session)
                httpCode = 400;
                httpMsg = 'Bad Request';
            else
                httpCode = 204;
                httpMsg = 'No Content';
                replyVersion = MCPConstants.protocolVersion;
            end

        else
            % POST. Decode first: knowing whether the session requirement
            % applies means knowing whether this is the initialize call.
            %
            % -32700 means exactly "no JSON value could be read": a body that
            % is empty, or that does not decode. Anything that did decode is
            % valid JSON, and whether it is a request is the envelope check's
            % question (-32600). The empty case is decided here, from the raw
            % bytes, because decoding cannot: an empty body and the valid
            % JSON value null both come out as [].
            first = firstJSONByte(request.Body);
            if isempty(first)
                error("prodserver:mcp:ParseError", ...
                    "Request body contains no JSON value.");
            end
            try
                jrpc = prodserver.mcp.internal.decodeBody(request);
            catch decodeFailure
                error("prodserver:mcp:ParseError", ...
                    "Request body is not valid JSON: %s", ...
                    decodeFailure.message);
            end

            % jsondecode returns the same scalar struct for [{...}] as for
            % {...}, so a batch of one would otherwise run as a single
            % request. Restoring the array lets the envelope check refuse it
            % as the batch it is, and replies with a null id: the id inside
            % belongs to a member, not to the request that was refused.
            if first == '['
                jrpc = {jrpc};
            end

            jrpc = prodserver.mcp.handler.internal.validateEnvelope(jrpc);

            % No id member means a notification: no response body, ever.
            isNotification = ~isfield(jrpc,"id");

            % initialize is exempt because it is where the session comes
            % from, and notifications are exempt because a 400 is a reply and
            % notifications do not get replies.
            isExempt = isNotification || ...
                strcmpi(string(jrpc.method),"initialize");
            if ~isExempt && isBlank(session)
                httpCode = 400;
                httpMsg = 'Bad Request';
            else
                [result, httpCode, httpMsg, msgHeaders] = handlePost(jrpc);
                replyVersion = MCPConstants.protocolVersion;

                % Some handlers may manage the JSON-encoding themselves,
                % for their own mysterious reasons. They will indicate
                % they've done so by setting the message header
                % Content-Type to "application/json"
                ct = "";
                if ~isempty(msgHeaders)
                    ct = getHeaderValue(MCPConstants.ContentType,msgHeaders);
                end

                if strcmpi(ct,Constants.MIMETypeJSON)
                    data = result;
                elseif ~isempty(result)
                    data = jsonencode(result);
                end
            end
        end
    catch me
        result = prodserver.mcp.handler.internal.handleError(jrpc,me);

        % A JSON-RPC error is not necessarily an HTTP transport error:
        % protocol/client-level errors (parse, invalid request, method not
        % found, invalid params, resource not found) are carried in the body
        % over HTTP 200, and only a genuine internal error maps to HTTP 500.
        code = MCPConstants.ErrorInternalError;
        if prodserver.mcp.internal.hasField(result, "error.code")
            code = result.error.code;
        end
        [httpCode, httpMsg] = ...
            prodserver.mcp.handler.internal.errorHttpStatus(code);

        data = jsonencode(result);
        msgHeaders = {};
    end

    % A notification gets an acknowledgement and nothing else, even when
    % handling it failed: JSON-RPC forbids replying to a request that has no
    % id, so there is nobody to report the error to.
    if isNotification
        httpCode = 202;
        httpMsg = 'Accepted';
        data = [];
        msgHeaders = {};
    end

    % Content-Type describes a body. Advertising application/json on a 202 or
    % 204 promises a body that is not there, so the header follows the data,
    % not the handler's encoding choice.
    %
    % Content-Length is deliberately NOT set here. MPS derives it from the body
    % it sends -- including the empty body, which it frames as
    % Content-Length: 0 on its own. Setting it here as well put two copies of
    % the header on every bodiless response over the wire, which no unit test
    % can see because the duplicate is created downstream of this struct. A
    % handler that volunteers a length can only ever agree with MPS or
    % contradict it, and neither is worth a duplicate header. Any length a
    % handler did set is dropped for the same reason.
    if ~isempty(data)
        if isempty(getHeaderValue(MCPConstants.ContentType,msgHeaders))
            msgHeaders = vertcat(msgHeaders, ...
                {MCPConstants.ContentType, char(Constants.MIMETypeJSON)});
        end
    else
        msgHeaders = dropHeader(msgHeaders, MCPConstants.ContentType);
    end
    msgHeaders = dropHeader(msgHeaders, MCPConstants.ContentLength);

    headers = vertcat({'Server' char(Constants.ServerHeader)}, headers, ...
        msgHeaders);
    if ~isempty(replyVersion)
        headers = vertcat(headers, ...
            {MCPConstants.ProtocolVersion char(replyVersion)});
    end
    if ~isempty(data)
        body = unicode2native(data,'UTF-8');
    else
        body = uint8.empty(1,0);
    end
    response = struct( ...
        'ApiVersion',[1 0 0], ...
        'HttpCode',httpCode, ...
        'HttpMessage',httpMsg, ...
        'Headers', {headers}, ...
        'Body', body);
end


function response = refusal(httpCode, httpMsg, extraHeaders)
%refusal A transport-level refusal: an HTTP error status and nothing else.
%   The request never reached the JSON-RPC layer, so there is no JSON-RPC
%   error to report and no body to describe. No Content-Type is sent because
%   there is no content to type, and no Content-Length because MPS frames the
%   empty body as Content-Length: 0 itself -- stating it here too put the
%   header on the wire twice.
    arguments
        httpCode (1,1) double
        httpMsg char
        extraHeaders cell = cell(0,2)
    end

    import prodserver.mcp.internal.Constants

    headers = [ ...
        {'Server' char(Constants.ServerHeader)}; ...
        extraHeaders];

    response = struct( ...
        'ApiVersion',[1 0 0], ...
        'HttpCode',httpCode, ...
        'HttpMessage',httpMsg, ...
        'Headers', {headers}, ...
        'Body', uint8.empty(1,0));
end


function tf = demandsEventStream(value)
%demandsEventStream True when the client will accept nothing but an SSE stream.
%   Absent Accept means */* and is permitted. Otherwise the header is a
%   comma-separated list of media ranges, each optionally carrying ;q= and
%   other parameters that do not matter here. The answer is yes only when the
%   client named text/event-stream AND left no way to send it JSON -- a client
%   listing both, which is what the spec asks for, is served normally.

    tf = false;
    if isempty(value)
        return
    end

    ranges = prodserver.mcp.internal.mediaType(split(string(value), ","));

    wantsStream = any(ranges == "text/event-stream");
    acceptsJSON = any(ismember(ranges, ...
        ["application/json" "application/*" "*/*"]));

    tf = wantsStream && ~acceptsJSON;
end


function tf = isUnsupportedMediaType(value)
%isUnsupportedMediaType True for a request Content-Type this server refuses.
%   Absent means JSON and is permitted. Otherwise only application/json is
%   accepted, compared by bare media type, so "Application/JSON;
%   charset=utf-8" passes and "application/jsonx" does not.

    if isBlank(value)
        tf = false;
    else
        tf = prodserver.mcp.internal.mediaType(value) ~= ...
            prodserver.mcp.internal.Constants.MIMETypeJSON;
    end
end


function c = firstJSONByte(body)
%firstJSONByte The first byte of the raw body that is not JSON whitespace.
%   JSON whitespace is space, tab, line feed and carriage return (RFC 8259
%   §2). Empty when the body holds nothing else. The raw bytes answer two
%   questions the decoded value cannot: whether there was a value at all
%   (null and an empty body both decode to []), and whether it was an array
%   (a one-element array decodes to the object it contains).

    body = uint8(body);
    c = char(body(find(~ismember(body, uint8([32 9 10 13])), 1)));
end


function tf = isBlank(value)
%isBlank True for a header value that is absent, empty, or only whitespace.
%   This is the whole of the session-id check. The value is deliberately not
%   validated further: the server cannot track sessions across MATLAB
%   Production Server workers, so it has no basis on which to call any
%   particular non-empty id wrong. Note this is unrelated to
%   prodserver.mcp.validation.mustBeSessionID, which describes the RFC 7329
%   "SID:<type>:<realm>:<uuid>" form used by the io URI-marshalling layer --
%   MCP session ids on the wire are bare UUIDs and do not match it.

    tf = isempty(value) || all(strlength(strtrim(string(value))) == 0);
end


function tf = isUnsupportedVersion(value)
%isUnsupportedVersion True for an MCP-Protocol-Version this server rejects.
%   An absent header is permitted: the framework's own client omits it on
%   initialize, notifications/initialized, */list and DELETE.

    if isBlank(value)
        tf = false;
    else
        tf = ~isequal(strtrim(string(value)), ...
            prodserver.mcp.MCPConstants.protocolVersion);
    end
end


function hdrs = dropHeader(hdrs, name)
%dropHeader Remove every row naming the given header from an Nx2 cell array.

    if isempty(hdrs)
        return
    end
    keep = ~strcmpi(string(hdrs(:,1)), string(name));
    hdrs = hdrs(keep,:);
end


function [result, httpCode, httpMsg, msgHeaders] = handlePost(jrpc)

    mth = lower(jrpc.method);
    result = []; %#ok<NASGU>

    if strcmp(mth,"ping")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.ping(jrpc);

    elseif strcmp(mth,"initialize")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.initialize(jrpc);

    elseif contains(mth,"notifications/initialized")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.notifications.initialized(jrpc);

    elseif contains(mth,"notifications/cancelled")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.notifications.cancelled(jrpc);

    elseif contains(mth,"resources/list")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.resource.list(jrpc);

    elseif contains(mth,"resources/read")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.resource.read(jrpc);

    elseif contains(mth,"tools/list")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.tools.list(jrpc);

    elseif contains(mth,"tools/call")
        [result, httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.tools.call(jrpc);

    else
        % Includes prompts/list and resources/templates/list: capabilities
        % this server does not advertise, so a client asking for them has
        % named a method that does not exist here.
        error("prodserver:mcp:UnsupportedRequest", ...
            "Invalid or unsupported MCP method %s", mth);
    end
end
