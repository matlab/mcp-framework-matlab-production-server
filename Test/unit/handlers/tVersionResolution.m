classdef tVersionResolution < matlab.unittest.TestCase
% End-to-end status and code for the two questions mcpHandler settles before
% it has an adapter: which protocol a request is speaking, and whether the
% version it names is one this server serves.
%
% Deliberately NOT built on MCPHandlerBase, and deliberately not parameterized
% by version. The version is not an input to these tests, it is the subject:
% each one states an envelope by hand -- a header contradicting _meta, a
% version no adapter claims, an `initialize` carrying _meta -- which is
% precisely the envelope the base's applyProtocol would overwrite. Several of
% them are claims about a PAIR of revisions disagreeing, which a per-version
% parameter cannot express at all.
%
% The requests that are expected to succeed use `ping`, `initialize` and
% DELETE, which no tool definition file is needed to answer. Everything else
% is rejected during routing and never reaches a handler. So this suite needs
% no tool fixtures, and a failure here points at routing rather than at a
% fixture that did not load.

% Copyright 2026 The MathWorks, Inc.

    properties (Access = private)
        baseRequest
    end

    methods (TestMethodSetup)
        function buildBaseRequest(test)
            test.baseRequest = struct( ...
                'ApiVersion', [1 0 0], ...
                'Headers', {{'Server' ...
                    'MATLAB Production Server/Model Context Protocol (v1.0)'}});
        end
    end

    methods (Access = private)

        function response = post(test, body, headers)
        %post POST a body with exactly the given extra headers, and no more.
            arguments
                test
                body
                headers = cell(0,2)
            end
            import prodserver.mcp.MCPConstants

            req = test.baseRequest;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}; ...
                headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Method = "POST";
            req.Path = "/prime/mcp";
            req.Body = unicode2native(body,"UTF-8");

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);
        end

        function decoded = verifyRejected(test, response, httpCode, errorCode)
        %verifyRejected Assert the HTTP status and JSON-RPC code of a rejection.
            decoded = prodserver.mcp.internal.decodeBody(response);
            wire = native2unicode(response.Body,"UTF-8");
            test.verifyEqual(response.HttpCode, httpCode, ...
                "HTTP status; body was " + wire);
            test.verifyTrue(prodserver.mcp.internal.hasField(decoded, ...
                'error.code'), "No error.code; body was " + wire);
            test.verifyEqual(decoded.error.code, errorCode, ...
                "JSON-RPC code; body was " + wire);
        end

        function decoded = verifyServed(test, response, id)
        %verifyServed Assert the request was answered, not rejected.
            decoded = prodserver.mcp.internal.decodeBody(response);
            wire = native2unicode(response.Body,"UTF-8");
            test.verifyEqual(response.HttpCode, 200, wire);
            test.verifyFalse(prodserver.mcp.internal.hasField(decoded,'error'), ...
                "Expected no error; body was " + wire);
            test.verifyEqual(decoded.id, id);
        end

        function body = metaBody(~, id, method, version)
        %metaBody A 2026-07-28 request declaring the given version.
            body = sprintf(['{ "jsonrpc": "2.0", "id": %d, "method": "%s", ' ...
                '"params": { "_meta": { ' ...
                '"io.modelcontextprotocol/protocolVersion": "%s", ' ...
                '"io.modelcontextprotocol/clientCapabilities": {} } } }'], ...
                id, method, version);
        end

    end

    methods (Test)

        function unknownMetaVersionIs400AndNamesWhatIsSupported(test)
        % UnsupportedProtocolVersionError declares `supported` and
        % `requested` without `?` in schema.ts, so neither is optional. A
        % client that guessed wrong cannot recover without them.
            C = prodserver.mcp.protocol.v20260728.Constants;

            body = test.metaBody(3, "tools/list", "1999-01-01");
            decoded = test.verifyRejected(test.post(body), 400, ...
                C.ErrorUnsupportedVersion);

            supported = string(decoded.error.data.supported);
            test.verifyTrue(ismember("2025-06-18", supported), ...
                "supported must list the 2025-06-18 revision");
            test.verifyTrue(ismember("2026-07-28", supported), ...
                "supported must list the 2026-07-28 revision");
            test.verifyEqual(string(decoded.error.data.requested), ...
                "1999-01-01");
        end

        function supportedVersionsExcludeRoutingAliases(test)
        % 2024-11-05 and 2025-03-26 resolve to the 2025-06-18 adapter so
        % that requests naming them are served, but this server does not
        % implement those revisions and must not claim it does (D48).
            body = test.metaBody(4, "tools/list", "1999-01-01");
            decoded = test.verifyRejected(test.post(body), 400, ...
                prodserver.mcp.protocol.v20260728.Constants.ErrorUnsupportedVersion);

            supported = string(decoded.error.data.supported);
            test.verifyFalse(ismember("2024-11-05", supported));
            test.verifyFalse(ismember("2025-03-26", supported));
        end

        function headerContradictingMetaIs400WithMismatch(test)
        % The regression test for the defect this phase exists to avoid.
        % Attributing the request from MCP-Protocol-Version would route it
        % to the 2025-06-18 adapter, which makes no header/_meta comparison
        % anywhere, and this mandatory -32020 would be served as a 200.
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            body = test.metaBody(5, "tools/list", "2026-07-28");
            headers = {MCPConstants.ProtocolVersion, '2025-06-18'};

            test.verifyRejected(test.post(body, headers), 400, ...
                C.ErrorHeaderMismatch);
        end

        function mismatchIsReportedAheadOfAnUnknownVersion(test)
        % Both are 400, so the status cannot tell these apart; the code can,
        % and -32020 is the specific diagnosis the spec mandates for this
        % comparison. An unknown version in _meta must not mask it.
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            body = test.metaBody(6, "tools/list", "2027-01-01");
            headers = {MCPConstants.ProtocolVersion, '2026-07-28'};

            test.verifyRejected(test.post(body, headers), 400, ...
                C.ErrorHeaderMismatch);
        end

        function requestNamingNoProtocolIs400(test)
        % No _meta, not an initialize, no session header. Nothing in the
        % request says what it speaks, and we answer as though it were a
        % 2026-07-28 request that forgot its _meta.
            body = ['{ "jsonrpc": "2.0", "id": 7, "method": "tools/list",' ...
                '"params": {} }'];

            test.verifyRejected(test.post(body), 400, ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function unknownHeaderVersionOnV20250618RequestIs400(test)
        % 2025-06-18 makes an unsupported MCP-Protocol-Version a hard 400.
        % Before this phase the header was never examined on this path and
        % the request was served as though it had said nothing.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants
            C = prodserver.mcp.protocol.v20260728.Constants;

            body = '{ "jsonrpc": "2.0", "id": 8, "method": "ping", "params": {} }';
            headers = {Constants.SessionId, char(matlab.lang.internal.uuid); ...
                MCPConstants.ProtocolVersion, '1999-01-01'};

            decoded = test.verifyRejected(test.post(body, headers), 400, ...
                C.ErrorUnsupportedVersion);
            test.verifyEqual(string(decoded.error.data.requested), ...
                "1999-01-01");
        end

        function v20250618RequestWithoutVersionHeaderIsServed(test)
        % Absence is not an error: a 2025-06-18 client need not send
        % MCP-Protocol-Version at all, and the spec says to assume
        % 2025-03-26. The check above must fire on present-and-unknown only
        % -- were it to fire on absence, every 2025-06-18 request would 400.
            import prodserver.mcp.protocol.v20250618.Constants

            body = '{ "jsonrpc": "2.0", "id": 9, "method": "ping", "params": {} }';
            headers = {Constants.SessionId, char(matlab.lang.internal.uuid)};

            test.verifyServed(test.post(body, headers), 9);
        end

        function aliasedHeaderVersionIsServed(test)
        % The 2025-03-26 alias is what honours the assume-this-version rule,
        % and it has to work when the client states the version explicitly
        % too -- otherwise a client doing exactly what the spec permits gets
        % the hard 400 meant for unsupported versions.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants

            body = '{ "jsonrpc": "2.0", "id": 10, "method": "ping", "params": {} }';
            headers = {Constants.SessionId, char(matlab.lang.internal.uuid); ...
                MCPConstants.ProtocolVersion, '2025-03-26'};

            test.verifyServed(test.post(body, headers), 10);
        end

        function initializeOutranksAV20260728VersionHeader(test)
        % The residual case, decided rather than left to code order:
        % initialize selects 2025-06-18 unconditionally, and with no _meta
        % present there is nothing for the header to contradict, so the
        % header is advisory. The giveaway that the 2025-06-18 adapter served
        % it is the minted session id.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.internal.getHeaderValue
            import prodserver.mcp.protocol.v20250618.Constants

            body = ['{ "jsonrpc": "2.0", "id": 11, "method": "initialize",' ...
                '"params": { "protocolVersion": "2025-06-18",' ...
                '"capabilities": {} } }'];
            headers = {MCPConstants.ProtocolVersion, '2026-07-28'};

            response = test.post(body, headers);
            decoded = test.verifyServed(response, 11);

            test.verifyEqual(string(decoded.result.protocolVersion), ...
                "2025-06-18");
            test.verifyNotEmpty( ...
                getHeaderValue(Constants.SessionId, response.Headers), ...
                "The 2025-06-18 adapter must have served this and minted a session");
        end

        function initializeCarryingMetaIsRoutedToV20260728(test)
        % Both adapters' shape predicates match this request, so something
        % has to break the tie. 2026-07-28 states the rule unconditionally
        % -- a request carrying per-request _meta is served according to
        % that revision -- so the newer one wins rather than the overlap
        % being reported as an ambiguity, which is what the previous
        % unique-match search did (and answered -32603/500).
        %
        % 2026-07-28 has no `initialize`; it replaced the handshake with
        % server/discover. So the right answer here is method-not-found, and
        % the STATUS is what proves which adapter produced it: 2026-07-28
        % maps method-not-found to 404, 2025-06-18 maps it to 200. A 200
        % here would mean the 2025-06-18 adapter had completed a handshake for
        % a client that asked for 2026-07-28 semantics.
        %
        % The required headers are supplied so the request survives header
        % validation and the rejection it earns is the one under test.
        % Without them it is rejected as -32020/400 instead, which proves
        % the routing just as well -- that code belongs to this revision
        % alone -- but says nothing about how method-not-found is mapped,
        % and the mapping is half of what this test is for.
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            body = test.metaBody(12, "initialize", "2026-07-28");
            headers = {MCPConstants.ProtocolVersion, char(C.Version); ...
                C.McpMethod, 'initialize'};

            test.verifyRejected(test.post(body, headers), 404, ...
                MCPConstants.ErrorMethodNotFound);
        end

        function pingIsNotAV20260728Method(test)
        % The 2026-07-28 revision removed ping. A ping carrying _meta must
        % be method-not-found (404), not answered. Liveness checks under
        % this revision use GET /<archive>/ping or server/discover.
            import prodserver.mcp.MCPConstants
            C = prodserver.mcp.protocol.v20260728.Constants;

            body = test.metaBody(13, "ping", "2026-07-28");
            headers = {MCPConstants.ProtocolVersion, char(C.Version); ...
                C.McpMethod, 'ping'};

            test.verifyRejected(test.post(body, headers), 404, ...
                MCPConstants.ErrorMethodNotFound);
        end

        function bareDeleteIsStill405(test)
        % The rename from UnknownProtocol to UnattributableRequest is caught
        % by exact string comparison in mcpHandler. If the two fall out of
        % step this DELETE stops being a 405 and becomes a 400 error
        % response, silently -- which is why the rename and the catch had to
        % land together.
            import prodserver.mcp.MCPConstants

            req = test.baseRequest;
            req.Method = "DELETE";
            req.Path = "/prime/mcp";
            req.Headers = [req.Headers; {MCPConstants.ContentLength, '0'}];

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyEqual(response.HttpCode, 405, ...
                native2unicode(response.Body,"UTF-8"));
            test.verifyEmpty(response.Body, ...
                "A 405 carries no JSON-RPC error body");
        end

        function sessionDeleteIsStillAcknowledged(test)
        % The other side of the same catch: a DELETE that names a session
        % must route to the session-based adapter and be acknowledged, so the
        % 405 above is specifically about being unattributable rather than
        % about DELETE being unsupported.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants

            session = char(matlab.lang.internal.uuid);
            req = test.baseRequest;
            req.Method = "DELETE";
            req.Path = "/prime/mcp";
            req.Headers = [req.Headers; ...
                {Constants.SessionId, session}; ...
                {MCPConstants.ContentLength, '0'}];

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyEqual(response.HttpCode, 204, ...
                native2unicode(response.Body,"UTF-8"));

            % The session id is echoed back exactly ONCE. responseHeaders is
            % the sole header authority for this revision; handleDelete
            % returning the id as well would duplicate the header, and a
            % duplicate Mcp-Session-Id is not something a client has to make
            % sense of. Asserting the count, not just the presence, is the
            % only form of this check that catches that.
            names = string(response.Headers(:,1));
            sessionRows = names == string(Constants.SessionId);
            test.verifyEqual(nnz(sessionRows), 1, ...
                "Response must echo Mcp-Session-Id exactly once");
            test.verifyEqual(string(response.Headers{sessionRows,2}), ...
                string(session), "Echoed session id must match the request");
        end

        function deleteWithMalformedBodyIsParseError(test)
        % XD1 residue: a DELETE body, when there is one, is decoded
        % strictly. The permissive decode let malformed JSON escape as a
        % raw MATLAB:json error, and so as -32603/500.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants

            body = '{ "jsonrpc": "2.0", ';
            req = test.baseRequest;
            req.Method = "DELETE";
            req.Path = "/prime/mcp";
            req.Headers = [req.Headers; ...
                {Constants.SessionId, char(matlab.lang.internal.uuid)}; ...
                {MCPConstants.ContentType, 'application/json'}; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body,"UTF-8");

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyRejected(response, 400, MCPConstants.ErrorParseError);
        end

        function pathNamingNoServerIs404(test)
        % XD1 residue: InvalidServerURL had no pre-detection mapping, so it
        % was reported as an internal error.
            import prodserver.mcp.MCPConstants

            body = '{ "jsonrpc": "2.0", "id": 1, "method": "ping" }';
            req = test.baseRequest;
            req.Headers = [req.Headers; ...
                {MCPConstants.ContentType, 'application/json'}; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Method = "POST";
            req.Path = "/";
            req.Body = unicode2native(body,"UTF-8");

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyRejected(response, 404, MCPConstants.ErrorInvalidRequest);
        end

        function blankSessionIdIsNoSession(test)
        % XD5: a whitespace-only Mcp-Session-Id names no session. It must
        % not attribute the request to 2025-06-18, and must not be echoed.
            import prodserver.mcp.protocol.v20250618.Constants

            body = ['{ "jsonrpc": "2.0", "id": 7, "method": "tools/list",' ...
                '"params": {} }'];
            response = test.post(body, {Constants.SessionId, '   '});

            % Nothing else says what the request speaks, so it is the
            % unattributable 400 of requestNamingNoProtocolIs400.
            test.verifyRejected(response, 400, ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
            names = lower(string(response.Headers(:,1)));
            test.verifyFalse(any(names == lower(Constants.SessionId)), ...
                "A blank session id must not be echoed");
        end

        function blankSessionDeleteIs405(test)
        % XD5, DELETE: a blank session id is the bare DELETE, not a
        % session termination.
            import prodserver.mcp.MCPConstants
            import prodserver.mcp.protocol.v20250618.Constants

            req = test.baseRequest;
            req.Method = "DELETE";
            req.Path = "/prime/mcp";
            req.Headers = [req.Headers; ...
                {Constants.SessionId, ' '}; ...
                {MCPConstants.ContentLength, '0'}];

            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);

            test.verifyEqual(response.HttpCode, 405, ...
                native2unicode(response.Body,"UTF-8"));
        end
    end

end
