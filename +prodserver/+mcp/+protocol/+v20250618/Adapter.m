classdef Adapter < prodserver.mcp.protocol.Adapter
%Adapter MCP protocol adapter for v2025-06-18.
%   This revision negotiates once, in `initialize`, and carries the agreement
%   forward in an Mcp-Session-Id header.
%   Handles session-based protocol: initialize handshake, session ID
%   headers, ping, and delegates shared methods to ProtocolDispatcher.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Version = prodserver.mcp.protocol.v20250618.Constants.Version
        InputErrorsAreToolErrors = ...
            prodserver.mcp.protocol.v20250618.Constants.InputErrorsAreToolErrors
    end

    methods
        function [result, httpCode, httpMsg, msgHeaders] = handlePost(obj, request, jrpc)
            mth = lower(string(jrpc.method));

            % Every request but initialize must carry a session this server
            % issued: 404 otherwise, before anything runs. The same decoding
            % gives the client's capabilities.
            if mth ~= "initialize"
                caps = obj.requireKnownSession(request);
            end

            % No notification arms here: mcpHandler acknowledges every
            % notifications/* POST at stage B, ahead of both the envelope
            % check and detection, so handlePost is only ever reached by a
            % request. These arms were live before that carve-out existed;
            % keeping them now would be unreachable code that also
            % contradicts dispatchNotification's claim to be the single,
            % protocol-independent notification table.
            if mth == "initialize"
                % The archive name becomes serverInfo.title.
                serverName = prodserver.mcp.internal.serverNameFromPath(request);
                [result, httpCode, httpMsg, msgHeaders] = ...
                    prodserver.mcp.protocol.v20250618.initialize(jrpc, serverName);

            elseif mth == "ping"
                [result, httpCode, httpMsg, msgHeaders] = ...
                    prodserver.mcp.protocol.v20250618.ping(jrpc);

            else
                [result, httpCode, httpMsg, msgHeaders] = ...
                    prodserver.mcp.handler.ProtocolDispatcher.instance( ...
                        ).dispatch(jrpc, obj.requestContext(request, jrpc, ...
                            Capabilities=caps));
            end
        end

        function [result, httpCode, httpMsg, msgHeaders] = handleDelete(obj, request)
            % Only a session this server issued can be terminated.
            obj.requireKnownSession(request);

            % Acknowledge session termination. The session id is echoed
            % back through responseHeaders (the single header authority for
            % this protocol), so no message-specific headers are needed
            % here -- returning them too would duplicate Mcp-Session-Id.
            [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(204);
            result = [];
            msgHeaders = {};
        end

        function caps = clientCapabilities(~, request, ~)
        %clientCapabilities The client declares its capabilities once, in
        %   initialize, which puts them in the session ID it issues (see
        %   encodeSession). Every later request sends that ID back. None if
        %   the request has no readable session ID; handlePost has already
        %   refused one that isn't readable.
            [~, caps] = prodserver.mcp.protocol.v20250618.decodeSession( ...
                prodserver.mcp.protocol.v20250618.Adapter.sessionOf(request));
        end

        function aliases = versionAliases(~)
        %versionAliases Older version strings this adapter serves.
        %   Routing only -- see Adapter.versionAliases.
        %
        %   2025-03-26: 2025-06-18, Protocol Version Header, says that if no
        %   MCP-Protocol-Version header is received the server SHOULD assume
        %   2025-03-26. This alias is what honours that -- and it is
        %   load-bearing in its own right, because a 2025-06-18 client may
        %   legitimately send 2025-03-26 in the header, and an unsupported
        %   version there is a hard 400.
        %
        %   2024-11-05: an older client, served by this revision.
            aliases = ["2024-11-05" "2025-03-26"];
        end

        function answer = preDetectionError(obj, identifier, jrpc, request)
        %preDetectionError This revision's answer when a version header it
        %   cannot support is rejected during resolution.
        %
        %   Reachable: an `initialize` request attributes here by shape, and
        %   ProtocolRegistry.resolve then looks up the MCP-Protocol-Version
        %   header, which raises if the header names a revision this server
        %   does not implement.
        %
        %   -32022 is a 2026-07-28 code being returned to a 2025-06-18
        %   client. That is permitted rather than mandated: the MUST NOT on
        %   the -32020..-32099 range binds 2026-07-28 implementations, not
        %   earlier ones. The alternative is inventing a code, or answering
        %   400 with no JSON-RPC body at all, and the `supported` list is the
        %   one thing that actually helps the caller recover.
        %
        %   HeaderMismatch is not answered here: it compares a header against
        %   params._meta, which a request attributed to this revision does not
        %   carry. Returning [] leaves it to the neutral arms.
            answer = [];
            if startsWith(identifier, "prodserver:mcp:UnsupportedProtocolVersion")
                answer = obj.unsupportedVersionAnswer( ...
                    prodserver.mcp.protocol.v20250618.Constants.ErrorUnsupportedVersion, ...
                    jrpc, request);
            end
        end

        function [result, httpCode, httpMsg] = formatError(~, me, jrpc)
            % mapErrorCode owns both the code and the status: status keys off
            % the exception identifier, not the numeric code. errorResponse
            % owns the envelope, which is identical for every protocol.
            [result, httpCode, httpMsg] = prodserver.mcp.jsonrpc.errorResponse( ...
                me, jrpc, @prodserver.mcp.protocol.v20250618.mapErrorCode);
        end

        % No postEncode override: this revision mangles no field names of
        % its own. Its only entry was the UI extension, which is
        % revision-neutral and is now applied by the base class for every
        % revision -- restoreJSONFields here was a one-row table that
        % duplicated the base behaviour and hid it from 2026-07-28.

        function headers = responseHeaders(~, request, jrpc)
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants

            headers = {};

            % initialize is the header authority for its own response: it
            % mints the session (which replaces any the request carried,
            % ND3) and states the version it negotiated (ND4). Echoing the
            % request here as well would send two session ids, and a
            % version header contradicting the body.
            if ~isempty(jrpc) && isstruct(jrpc) && isscalar(jrpc) && ...
                    isfield(jrpc, 'method') && ...
                    strcmpi(string(jrpc.method), "initialize")
                return
            end

            % Echo only a session ID this server issued. Anything else is
            % refused with 404, and echoing a client-supplied value would
            % let it make the response headers arbitrarily long: past
            % about 4 KB, Production Server fails the response after the
            % request has run.
            session = prodserver.mcp.protocol.v20250618.Adapter.sessionOf(request);
            [~, ~, known] = prodserver.mcp.protocol.v20250618.decodeSession(session);
            if known
                % char: Production Server requires char header values,
                % and getHeaderValue returns a string.
                headers = vertcat(headers, {Constants.SessionId char(session)});
            end
            % Only initialize carries params.protocolVersion, and it returned
            % above, so the header is the only source left. Read through
            % headerVersion, as routing reads it, so the echo is the trimmed
            % value ProtocolRegistry.resolve routed on. char, as for the
            % session id.
            pv = prodserver.mcp.internal.headerVersion(request);
            if strlength(pv) > 0
                headers = vertcat(headers, ...
                    {char(MCPConstants.ProtocolVersion) char(pv)});
            end
        end
    end

    methods (Static, Access = private)
        function caps = requireKnownSession(request)
        %requireKnownSession Refuse a session ID this server didn't issue.
        %   Returns the capabilities the session ID carries, or
        %   ClientCapabilities.none() if the request has no session ID.
        %   A plain UUID from before session IDs carried capabilities, a
        %   malformed ID and an over-long one are all unknown sessions. The
        %   2025-06-18 answer is 404, and a client that gets it MUST start a
        %   new session, so a host re-initializes and gets a token. A request
        %   with no session ID isn't checked here: it either is initialize,
        %   or wasn't attributed to this revision at all.
            session = prodserver.mcp.protocol.v20250618.Adapter.sessionOf(request);
            [~, caps, known] = prodserver.mcp.protocol.v20250618.decodeSession(session);
            if ~isempty(session) && ~known
                error("prodserver:mcp:SessionNotFound", "Session not found. " + ...
                    "Start a new session: send initialize without an " + ...
                    "Mcp-Session-Id.");
            end
        end
    end

    methods (Static)
        function tf = matches(request, jrpc)
            tf = false;
            if ~isempty(jrpc) && isfield(jrpc, 'method') && ...
                    strcmpi(string(jrpc.method), "initialize")
                tf = true;
                return
            end
            if ~isempty(request) && isfield(request, 'Headers') && ...
                    ~isempty(request.Headers)
                session = prodserver.mcp.protocol.v20250618.Adapter.sessionOf(request);
                if ~isempty(session)
                    tf = true;
                end
            end
        end

        function session = sessionOf(request)
        %sessionOf The request's Mcp-Session-Id, or empty if it has none.
        %   A whitespace-only value counts as none (XD5): it names no
        %   session, so it must neither attribute the request to this
        %   revision nor be echoed back as though it did.
            import prodserver.mcp.protocol.v20250618.Constants
            session = string.empty;
            if isempty(request) || ~isfield(request, 'Headers') || ...
                    isempty(request.Headers)
                return
            end
            session = prodserver.mcp.internal.getHeaderValue( ...
                Constants.SessionId, request.Headers);
            if ~isempty(session) && strlength(strip(string(session))) == 0
                session = string.empty;
            end
        end
    end

end
