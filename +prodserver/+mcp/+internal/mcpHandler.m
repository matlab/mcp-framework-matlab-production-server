function response = mcpHandler(request)
%mcpHandler Custom web handler for MCP JSON RPC protocol.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.Constants

    % Everything the response is assembled from, set before anything can
    % fail, so no path reaches the assembly with one of them unassigned.
    data = [];
    jrpc = [];
    adapter = [];
    % The adapter the request's SHAPE selected, kept separately because it
    % survives a failed version resolution. resolve raises HeaderMismatch
    % and UnsupportedProtocolVersion while holding it, and those are the
    % two failures whose correct code depends on which revision the
    % request declared -- so the error path asks this adapter rather than
    % naming a revision. Stays [] when attribution itself failed.
    attributed = [];
    result = [];
    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(500);
    msgHeaders = {};
    protoHeaders = {};

    % Transport gates, ahead of the path, the server name and the metrics
    % (XD3): none of them needs anything the request carries beyond its
    % method and headers. GET used to sit after the server-name check, so
    % a GET on a path with no server segment was a 500, not a 405.
    %
    % Only POST and DELETE: GET is not supported for any protocol version
    % (D32) -- and 405 is exactly how 2025-06-18 says a server with no SSE
    % stream must answer one.
    if ~any(strcmpi(request.Method, ["post", "delete"]))
        [httpCode, httpMsg, msgHeaders] = ...
            prodserver.mcp.handler.internal.methodNotAllowed();
        response = assemble(httpCode, httpMsg, msgHeaders, data);
        return
    end
    % Every response to a POST is JSON. A client that says it cannot read
    % JSON gets 406 rather than a body it has declared it cannot use
    % (XD22, decided 2026-10-02).
    if strcmpi(request.Method, "post") && isfield(request, "Headers") && ...
            ~prodserver.mcp.internal.acceptsJson(request.Headers)
        [code, reason] = prodserver.mcp.handler.internal.httpStatus(406);
        response = assemble(code, reason, {}, data);
        return
    end

    try
        % Need server name for metrics. Expecting URLs to look like this:
        %   /<server>/mcp
        serverName = prodserver.mcp.internal.serverNameFromPath(request.Path);
        if strlength(serverName) == 0
            error("prodserver:mcp:InvalidServerURL", ...
                "Cannot determine server name from request URL '%s'.", ...
                request.Path);
        end

        % Record elapsed time -- this time measures overhead and tool
        % call time.
        serverTimeMetric = MCPConstants.MCPMetricPrefix + serverName + "_ElapsedTime";
        et = tic();
        elapsed = onCleanup(@()prodserver.metrics.incrementCounter(serverTimeMetric,toc(et)));

        % Count the number of times mcpHandler is called.
        prodserver.metrics.incrementCounter(MCPConstants.MCPRequestMetric,1);

        % Record number of calls
        serverMetric = MCPConstants.MCPMetricPrefix + serverName + MCPConstants.MCPMetricSuffix;
        prodserver.metrics.incrementCounter(serverMetric,1)

        registry = prodserver.mcp.protocol.ProtocolRegistry.instance();

        switch lower(request.Method)
            case "post"
                % Stage A -- parse. strict=true turns a malformed body into
                % ParseError/-32700, an empty one into InvalidRequest/-32600
                % and an unsupported media type into 415, instead of letting
                % a raw MATLAB error fall through as -32603/500.
                jrpc = prodserver.mcp.internal.decodeBody(request, strict=true);

                % Stage B -- notification carve-out. A notification receives
                % no response at all (MUST NOT in both specs), so it is
                % acknowledged and dropped here, ahead of every check that
                % assumes a request. It must precede stage B' because a
                % notification legitimately has no id, and it must precede
                % detection because a 2026-07-28 notification legitimately
                % carries no _meta (header requirements for notification
                % POSTs are not defined by that revision).
                if isNotification(jrpc)
                    [result, httpCode, httpMsg, msgHeaders] = ...
                        dispatchNotification(jrpc);
                else
                    % Stage B' -- envelope.
                    prodserver.mcp.internal.validateEnvelope(jrpc);

                    % registry.detect's two steps, run separately so a
                    % resolution failure leaves `attributed` set. See
                    % ProtocolRegistry.detect for why the order matters.
                    attributed = registry.attribute(request, jrpc);
                    adapter = registry.resolve(attributed, request, jrpc);
                    [result, httpCode, httpMsg, msgHeaders] = ...
                        adapter.handlePost(request, jrpc);
                end
                % The notification branch above leaves adapter empty on
                % purpose -- a 202 carries no body and no protocol headers --
                % so guard postEncode rather than relying on every
                % notification handler returning an empty result forever.
                if ~isempty(result) && ~isempty(adapter)
                    data = prodserver.mcp.jsonrpc.encodeMessage(result);
                    data = adapter.postEncode(data);
                    msgHeaders = vertcat(msgHeaders, ...
                        {MCPConstants.ContentType, char(Constants.MIMETypeJSON)});
                end

            case "delete"
                % A session-termination DELETE carries no JSON-RPC body;
                % the protocol is detected from the request headers (the
                % Mcp-Session-Id, for revisions that have sessions), and the
                % matched adapter decides whether it honors termination.
                % A DELETE that no protocol claims cannot be attributed to
                % a session, so client-initiated termination does not apply
                % and the server reports Method Not Allowed.
                %
                % A body, if there is one, is decoded strictly: the
                % permissive decode let a malformed one escape as a raw
                % MATLAB:json error and so a 500 (XD1).
                if isfield(request, "Body") && ~isempty(request.Body)
                    jrpc = prodserver.mcp.internal.decodeBody(request, ...
                        strict=true);
                else
                    jrpc = prodserver.mcp.internal.decodeBody(request);
                end
                try
                    attributed = registry.attribute(request, jrpc);
                    adapter = registry.resolve(attributed, request, jrpc);
                catch detectErr
                    % Exact-match on the identifier, so this must be kept in
                    % step with the one ProtocolRegistry.attribute raises. A
                    % stale name here does not fail loudly: the error
                    % rethrows, the catch below maps it as a POST would, and
                    % a bare DELETE silently regresses from 405 to 400.
                    if detectErr.identifier == "prodserver:mcp:UnattributableRequest"
                        adapter = [];
                    else
                        rethrow(detectErr);
                    end
                end
                if isempty(adapter)
                    [httpCode, httpMsg, msgHeaders] = ...
                        prodserver.mcp.handler.internal.methodNotAllowed();
                else
                    [~, httpCode, httpMsg, msgHeaders] = ...
                        adapter.handleDelete(request);
                end
        end
        % No otherwise arm: the gate above admits only POST and DELETE.

        % Inside the try, so a failure here is mapped like any other rather
        % than escaping to Production Server as a raw MATLAB error.
        if ~isempty(adapter)
            protoHeaders = adapter.responseHeaders(request, jrpc);
        end

    catch me
        % The matched adapter maps the exception to a protocol-correct
        % JSON-RPC error code AND the HTTP status its spec mandates (e.g.
        % method-not-found is HTTP 200 for 2025-06-18 but 404 for
        % 2026-07-28). With no adapter, the failure happened before protocol
        % detection and is reported as a generic internal error.
        if ~isempty(adapter)
            [result, httpCode, httpMsg] = adapter.formatError(me, jrpc);
            data = adapter.postEncode(prodserver.mcp.jsonrpc.encodeMessage(result));
        else
            [result, httpCode, httpMsg] = ...
                prodserver.mcp.handler.internal.handleError( ...
                    jrpc, me, request, attributed);
            data = prodserver.mcp.jsonrpc.encodeMessage(result);
        end
        msgHeaders = {MCPConstants.ContentType, char(prodserver.mcp.internal.Constants.MIMETypeJSON)};

        % The error still deserves the revision's headers. If computing them
        % is what failed, the error being reported may be that very failure,
        % so do without rather than throw out of the error path.
        protoHeaders = {};
        if ~isempty(adapter)
            try
                protoHeaders = adapter.responseHeaders(request, jrpc);
            catch
            end
        end
    end

    response = assemble(httpCode, httpMsg, ...
        vertcat(protoHeaders, msgHeaders), data);
end

function response = assemble(httpCode, httpMsg, headers, data)
%assemble The custom web handler response structure. One place, so every
%   response -- gated, handled or failed -- carries the same Server header.
    import prodserver.mcp.MCPConstants

    headers = vertcat({'Server', MCPConstants.ServerHeader}, headers);
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

function tf = isNotification(jrpc)
%isNotification True for a JSON-RPC notification, identified by its method
%   name. Both specs namespace every notification under "notifications/".
    tf = false;
    if isempty(jrpc) || ~isstruct(jrpc) || ~isscalar(jrpc) || ...
            ~isfield(jrpc, 'method') || isempty(jrpc.method)
        return
    end
    if ~(ischar(jrpc.method) || isstring(jrpc.method))
        return
    end
    tf = startsWith(lower(string(jrpc.method)), "notifications/");
end

function [result, httpCode, httpMsg, msgHeaders] = dispatchNotification(jrpc)
%dispatchNotification Accept a notification and return no response body.
%   Both specs: the receiver MUST NOT send a response to a notification; the
%   transport binding answers an accepted notification with 202 and no body.
%   Protocol-independent by design -- notification handling needs no adapter,
%   and running it before detection is what keeps a 2026-07-28 notification
%   (which carries no _meta) from being rejected as unattributable.
    %
    %   A handler that throws does not change that (XD10): the catch-all
    %   answer would be a 500 with a JSON-RPC body, which is a response to
    %   something that MUST NOT get one. So any failure is swallowed into the
    %   same 202 an unrecognized notification gets.
    result = [];
    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(202);
    msgHeaders = {};
    try
        mth = lower(string(jrpc.method));

        if mth == "notifications/initialized"
            [result, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.notifications.initialized(jrpc);
        elseif mth == "notifications/cancelled"
            [result, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.notifications.cancelled(jrpc);
        end
        % Anything else is an unrecognized notification, and is still a
        % notification: accept and drop it rather than answering with an
        % error the sender MUST NOT receive. (Phase 4 records this as a
        % preference, not a conformance fix -- an HTTP error with an
        % id-less body is the spec's own enumerated alternative.)
    catch
        result = [];
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(202);
        msgHeaders = {};
    end
end
