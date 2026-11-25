classdef (Abstract) Adapter < handle
%Adapter Abstract base class for client-side MCP protocol adapters.
%   Template-method send handles ID assignment, encoding, HTTP
%   construction, and transport. Subclasses implement the protocol
%   envelope via prepareRequest and postEncode.
%
%   Use the static Adapter.create method to obtain an adapter:
%
%   client = prodserver.mcp.client.Adapter.create(endpoint)
%   client = prodserver.mcp.client.Adapter.create(endpoint, protocol="2026-07-28")
%   prodserver.mcp.client.Adapter.create(endpoint, action="clear")
%   prodserver.mcp.client.Adapter.create(action="clearAll")

% Copyright 2026 The MathWorks, Inc.

    properties (Abstract, Constant)
        Version string
    end

    properties (SetAccess = protected)
        Endpoint string
        RequestId double = 1
    end

    methods (Abstract)
        connect(obj, opts)
        disconnect(obj)
        [data, extraHeaders] = prepareRequest(obj, data)
        headers = protocolHeaders(obj)
    end

    methods

        function obj = Adapter(endpoint)
            obj.Endpoint = endpoint;
        end

        function id = nextId(obj)
            id = obj.RequestId;
            obj.RequestId = obj.RequestId + 1;
        end

        function response = send(obj, data, opts)
            arguments
                obj
                data (1,1) struct
                opts.timeout double {mustBePositive} = 60
                opts.retry double {mustBePositive} = ...
                    prodserver.mcp.internal.Constants.ArchiveRetry
                opts.delay double {mustBePositive} = ...
                    prodserver.mcp.internal.Constants.ArchiveDelay
                opts.label string = ""
                % Safe to send again if no answer came: true only for a
                % request that changes nothing (see sendRequest).
                opts.repeatable (1,1) logical = false
            end

            if ~isfield(data, 'id')
                data.id = obj.nextId();
            end

            [request, data] = obj.buildRequest(data);

            if strlength(opts.label) == 0 && isfield(data, 'method')
                opts.label = string(data.method);
            end
            response = prodserver.mcp.internal.sendRequest(request, ...
                obj.Endpoint, timeout=opts.timeout, retry=opts.retry, ...
                delay=opts.delay, label=opts.label, repeatable=opts.repeatable);
        end

        function [request, data] = buildRequest(obj, data)
        %buildRequest The HTTP POST that carries DATA in this revision.
        %   The one place a request is assembled, so that send and the
        %   version probe cannot build different envelopes. Returns DATA as
        %   prepareRequest left it.
            [data, extraHeaders] = obj.prepareRequest(data);

            json = prodserver.mcp.jsonrpc.encodeMessage(data);
            json = obj.postEncode(json);

            headers = [
                prodserver.mcp.internal.mcpPostHeaders(), ...
                extraHeaders
                ];
            body = matlab.net.http.MessageBody();
            body.Payload = uint8(json);
            request = matlab.net.http.RequestMessage('POST', headers, body);
        end

        function json = postEncode(~, json)
        end

        function [items, id] = list(obj, type, opts)
            arguments
                obj
                type prodserver.mcp.Primitive
                % As long as any request: a list is often the first request
                % to reach an archive, and a newly started server's worker
                % may be loading it.
                opts.timeout double {mustBePositive} = 60
                opts.retry double {mustBePositive} = ...
                    prodserver.mcp.internal.Constants.ArchiveRetry
                opts.delay double {mustBePositive} = ...
                    prodserver.mcp.internal.Constants.ArchiveDelay
            end
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.hasField

            for n = 1:numel(type)
                pfield = mcpName(type(n));
                data = struct();
                data.jsonrpc = MCPConstants.jrpcVersion;
                data.method = pfield + "/list";

                response = obj.send(data, timeout=opts.timeout, ...
                    retry=opts.retry, delay=opts.delay, repeatable=true);

                if hasField(response, "Body.Data.result." + pfield) == false
                    error("prodserver:mcp:BadListResponse", ...
                        "List %s returned successfully but " + ...
                        "without expected result field.", pfield);
                end
                items.(pfield) = response.Body.Data.result.(pfield);
                if ~iscell(items.(pfield))
                    items.(pfield) = num2cell(items.(pfield));
                end
            end
            id = obj.RequestId;
        end

    end

    methods (Static)

        function client = create(endpoint, opts)
        %create Create an Adapter for the given endpoint.
        %   Uses dual-era probing (server/discover then initialize
        %   fallback) with endpoint-keyed version caching.
            arguments
                endpoint string = ""
                opts.protocol string = "discover"
                opts.action string = "detect"
                opts.timeout double {mustBePositive} = 60
                opts.retry double {mustBePositive} = ...
                    prodserver.mcp.internal.Constants.ArchiveRetry
                opts.delay double {mustBePositive} = ...
                    prodserver.mcp.internal.Constants.ArchiveDelay
            end

            persistent cache
            if isempty(cache)
                cache = dictionary;
            end

            switch opts.action
                case "clear"
                    if strlength(endpoint) > 0 && ...
                            isConfigured(cache) && isKey(cache, endpoint)
                        cache = remove(cache, endpoint);
                    end
                    client = [];
                    return
                case "clearAll"
                    cache = dictionary;
                    client = [];
                    return
            end

            if opts.protocol == "discover"
                if isConfigured(cache) && isKey(cache, endpoint)
                    version = cache{endpoint};
                    client = createAdapter(endpoint, version);
                    return
                end
                [version, answered] = probe(endpoint, opts);
                % A guess made because the server didn't answer isn't
                % kept: the next call asks again.
                if answered
                    cache(endpoint) = {version};
                end
                client = createAdapter(endpoint, version);
            else
                client = createAdapter(endpoint, opts.protocol);
                cache(endpoint) = {opts.protocol};
            end
        end

    end

end

function [version, answered] = probe(endpoint, opts)
% The revision the server at ENDPOINT speaks. answered is false if it never
% answered -- every attempt timed out or was refused -- and VERSION, then
% 2025-06-18, is a guess.
    import prodserver.mcp.MCPConstants
    import prodserver.mcp.internal.hasField

    answered = false;

    data.jsonrpc = MCPConstants.jrpcVersion;
    data.method = "server/discover";
    data.id = 1;

    % Built by the adapter under test, not by hand. A second hand-rolled
    % envelope here is what made the required-header defect invisible: a
    % probe missing a header the server demands gets a 400 with no result
    % member, which is indistinguishable from "this server does not speak
    % 2026-07-28" and falls through to the 2025-06-18 answer below. Every
    % header this revision requires therefore has to come from the one place
    % that knows the full list.
    %
    % buildRequest rather than send: the probe sends from a client of a
    % revision the endpoint may not speak. The status retries every request
    % to the archive gets, since the probe is usually the first: a 404 may be
    % an archive still deploying. And the one resend sendRequest makes of a
    % request with no answer, as for any request that changes nothing, not
    % opts.retry of them: each waits the whole timeout.
    probeClient = prodserver.mcp.client.v20260728.Adapter(endpoint);
    request = probeClient.buildRequest(data);

    try
        response = prodserver.mcp.internal.sendRequest(request, ...
            endpoint, timeout=opts.timeout, retry=opts.retry, ...
            delay=opts.delay, label="server/discover", repeatable=true);
        answered = true;
        if hasField(response, 'Body.Data.result.supportedVersions')
            version = probeClient.Version;
            return
        end
    catch me
        % No archive answered, so nothing was learned about its revision,
        % and initialize would only wait again for the same 404.
        if me.identifier == "prodserver:mcp:UnknownArchive"
            rethrow(me);
        end
        % Any answer says the server doesn't speak this revision; a
        % timeout or a refused connection is no answer.
        answered = ~prodserver.mcp.internal.isTransientError(me, ...
            status=[]);
    end

    version = prodserver.mcp.client.v20250618.Adapter.Version;
end

function client = createAdapter(endpoint, version)
    switch version
        case prodserver.mcp.client.v20250618.Adapter.Version
            client = prodserver.mcp.client.v20250618.Adapter(endpoint);
        case prodserver.mcp.client.v20260728.Adapter.Version
            client = prodserver.mcp.client.v20260728.Adapter(endpoint);
        otherwise
            error("prodserver:mcp:UnsupportedProtocolVersion", ...
                "Unsupported protocol version: %s", version);
    end
end
