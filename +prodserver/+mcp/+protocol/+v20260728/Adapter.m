classdef Adapter < prodserver.mcp.protocol.Adapter
%Adapter MCP protocol adapter for v2026-07-28.
%   This revision dropped the handshake: every request restates the protocol
%   version and client capabilities in params._meta, and there is no session.
%   Handles sessionless protocol: _meta validation, header validation,
%   server/discover, and delegates shared methods to ProtocolDispatcher.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Version = prodserver.mcp.protocol.v20260728.Constants.Version
        InputErrorsAreToolErrors = ...
            prodserver.mcp.protocol.v20260728.Constants.InputErrorsAreToolErrors
    end

    methods
        function [result, httpCode, httpMsg, msgHeaders] = handlePost(obj, request, jrpc)
            import prodserver.mcp.MCPConstants

            C = prodserver.mcp.protocol.v20260728.Constants;

            [version, ~, ~] = ...
                prodserver.mcp.protocol.v20260728.validateMeta(jrpc);
            prodserver.mcp.protocol.v20260728.validateHeaders( ...
                request, jrpc, version);

            mth = lower(string(jrpc.method));

            % No notification arm here: mcpHandler acknowledges every
            % notifications/* POST at stage B, ahead of detection, because a
            % notification has no id for stage B' and carries no _meta for
            % this revision to attribute. handlePost is only ever reached by
            % a request, so a notification arm would be unreachable -- and
            % having one would contradict dispatchNotification's claim to be
            % the single, protocol-independent notification table.
            % No ping arm either: 2026-07-28 removed ping (and initialize),
            % so both fall through to the dispatcher's method-not-found.
            if mth == "server/discover"
                [result, httpCode, httpMsg, msgHeaders] = ...
                    prodserver.mcp.protocol.v20260728.discover(jrpc);

            else
                [result, httpCode, httpMsg, msgHeaders] = ...
                    prodserver.mcp.handler.ProtocolDispatcher.instance( ...
                        ).dispatch(jrpc, obj.Version);
            end

            % resultType goes on every result, cacheable or not. It is not a
            % caching flag: it says whether the result is complete or needs
            % more input, and this revision requires it on every result.
            % Only the caching hints are limited to particular methods.
            if ~isempty(result) && isfield(result, 'result')
                result.result.resultType = "complete";
                % The archive name becomes serverInfo.title.
                serverName = prodserver.mcp.internal.serverNameFromPath(request);
                result.result.(MCPConstants.MetaField).(C.MetaServerInfo_Field) = ...
                    prodserver.mcp.protocol.serverInfo(serverName);
                result.result = prodserver.mcp.protocol.v20260728.cacheHints( ...
                    result.result, mth);
            end
        end

        function [result, httpCode, httpMsg, msgHeaders] = handleDelete(~, ~)
            % No sessions in this revision, so nothing to terminate: as this
            % revision sees it, the endpoint accepts only POST.
            [httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.internal.methodNotAllowed('POST');
            result = [];
        end

        function [result, httpCode, httpMsg] = formatError(~, me, jrpc)
            % mapErrorCode owns both the code and the status. It MUST key off
            % the exception identifier: -32602 is overloaded, so the
            % missing-_meta family gets the mandated 400 while unknown
            % tool / unknown URI / invalid arguments stay 200. The previous
            % switch-on-code here could not express that distinction.
            % errorResponse owns the envelope, shared with every protocol.
            [result, httpCode, httpMsg] = prodserver.mcp.jsonrpc.errorResponse( ...
                me, jrpc, @prodserver.mcp.protocol.v20260728.mapErrorCode);
        end

        function version = statedVersion(~, jrpc)
        %statedVersion This revision states its version in params._meta.
            version = prodserver.mcp.protocol.v20260728.metaVersion(jrpc);
        end

        function checkStatedVersion(~, pv, stated)
        %checkStatedVersion The header must agree with _meta: -32020 if not.
            prodserver.mcp.protocol.v20260728.checkVersionHeader(pv, stated);
        end

        function answer = preDetectionError(obj, identifier, jrpc, request)
        %preDetectionError This revision's codes for the two failures that
        %   ProtocolRegistry.resolve can raise once _meta has attributed a
        %   request here. Both are mandated 400s with codes from this
        %   revision's reserved -32020..-32099 range.
            C = prodserver.mcp.protocol.v20260728.Constants;

            answer = [];
            if startsWith(identifier, "prodserver:mcp:HeaderMismatch")
                answer = prodserver.mcp.protocol.preDetectionAnswer( ...
                    C.ErrorHeaderMismatch);
            elseif startsWith(identifier, "prodserver:mcp:UnsupportedProtocolVersion")
                answer = obj.unsupportedVersionAnswer( ...
                    C.ErrorUnsupportedVersion, jrpc, request);
            end
        end

        function headers = responseHeaders(~, ~, ~)
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;
            headers = {MCPConstants.ProtocolVersion, char(C.Version)};
        end

        function data = postEncode(obj, data)
            % Superclass first, for the field names every revision shares;
            % then this revision's own _meta sub-field names.
            data = postEncode@prodserver.mcp.protocol.Adapter(obj, data);
            data = prodserver.mcp.protocol.v20260728.restoreJSONFields(data);
        end
    end

    methods (Static)
        function tf = matches(~, jrpc)
        %matches Shape predicate: does this request carry per-request _meta?
        %   "Per-request" is the spec's term, and it names specific keys:
        %   the io.modelcontextprotocol/* per-request protocol fields
        %   (protocolVersion, clientCapabilities, clientInfo, logLevel).
        %   The presence of params._meta alone is NOT the marker. Earlier
        %   revisions use _meta too -- progressToken, traceparent and friends
        %   are reserved in both eras -- and a 2025-06-18 client sending
        %   tools/list with {"_meta":{"progressToken":0}} must not be claimed
        %   by this revision and refused for lacking a protocolVersion.
        %
        %   Any one of the fields is enough, deliberately not protocolVersion
        %   alone. ProtocolRegistry.attribute uses this to pick an adapter
        %   from shape alone, before any version string is read; a _meta
        %   carrying clientCapabilities but no version is still unmistakably
        %   a request for this revision, and answering it with
        %   MissingProtocolVersion (-32602/400 from validateMeta) is far
        %   better than letting it fall through to UnattributableRequest.
        %
        %   The exact keys, not the io.modelcontextprotocol/ prefix: that
        %   prefix is reserved for every MCP-defined _meta key, including
        %   extension keys an earlier revision may send.
            tf = false;
            if isempty(jrpc)
                return
            end
            MetaField = prodserver.mcp.MCPConstants.MetaField;
            if ~prodserver.mcp.internal.hasField(jrpc, "params." + MetaField)
                return
            end
            C = prodserver.mcp.protocol.v20260728.Constants;
            perRequest = [C.MetaProtocolVersion_Field, ...
                C.MetaCapabilities_Field, C.MetaCapabilitiesAlt_Field, ...
                C.MetaClientInfo_Field, C.MetaLogLevel_Field];
            meta = jrpc.params.(MetaField);
            tf = isstruct(meta) && any(isfield(meta, perRequest));
        end
    end

end
