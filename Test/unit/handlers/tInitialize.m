classdef tInitialize < matlab.unittest.TestCase
% Test prodserver.mcp.protocol.v20250618.initialize (handle the MCP initialize request:
% negotiate protocol version, advertise capabilities, mint a session id).
%
% The handler is tested directly, and then end to end through mcpHandler,
% because two of its defects (ND3, ND4) were in the headers mcpHandler
% assembles around it, which a direct call cannot see.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Negotiated = "2025-06-18";
        Archive = "myArchive";
    end

    methods

        function jrpc = request(~, protocolVersion)
            jrpc.jsonrpc = "2.0";
            jrpc.id = 7;
            jrpc.params.protocolVersion = protocolVersion;
        end

        function verifyVersionHeader(test, msgHeaders, expected)
            import prodserver.mcp.MCPConstants
            rows = strcmpi(msgHeaders(:,1), MCPConstants.ProtocolVersion);
            test.assertEqual(nnz(rows), 1, ...
                "Exactly one MCP-Protocol-Version header");
            test.verifyClass(msgHeaders{rows,2}, "char");
            test.verifyEqual(string(msgHeaders{rows,2}), expected);
        end

        function response = post(test, protocolVersion, headers)
        %post initialize through mcpHandler, at /<Archive>/mcp.
            arguments
                test
                protocolVersion
                headers = cell(0,2)
            end
            import prodserver.mcp.MCPConstants
            jrpc = test.request(protocolVersion);
            jrpc.method = "initialize";
            body = jsonencode(jrpc);
            req = struct('ApiVersion', [1 0 0], 'Method', "POST", ...
                'Path', "/" + test.Archive + "/mcp");
            req.Headers = [{'Server', 'MATLAB Production Server'}; ...
                {MCPConstants.ContentType, 'application/json'}; headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body, "UTF-8");
            response = prodserver.mcp.internal.mcpHandler(req);
            prodserver.mcp.test.verifyConformantResponse(test, response);
        end

        function verifyNegotiation(test, requested)
        % The body and the header both carry the negotiated version.
            [result, ~, ~, msgHeaders] = ...
                prodserver.mcp.protocol.v20250618.initialize( ...
                    test.request(requested));
            test.verifyEqual(result.result.protocolVersion, test.Negotiated, ...
                "Negotiated version for requested " + requested);
            test.verifyVersionHeader(msgHeaders, test.Negotiated);
        end

    end

    methods (Test)

        function tNegotiatesProtocolAndIdentity(test)
            import prodserver.mcp.MCPConstants
            result = prodserver.mcp.protocol.v20250618.initialize(test.request("2025-06-18"));
            test.verifyEqual(result.id, 7);
            test.verifyEqual(result.jsonrpc, "2.0");
            r = result.result;
            test.verifyEqual(r.protocolVersion, "2025-06-18");
            % One source for the server's identity (ND10).
            test.verifyEqual(r.serverInfo.name, MCPConstants.ServerName);
            test.verifyEqual(r.serverInfo.version, MCPConstants.ServerVersion);
        end

        function tAdvertisesCapabilities(test)
            result = prodserver.mcp.protocol.v20250618.initialize(test.request("2025-06-18"));
            r = result.result;
            test.verifyFalse(r.capabilities.tools.listChanged);
            test.verifyFalse(r.capabilities.resources.listChanged);
        end

        function tSessionIdHeader(test)
            import prodserver.mcp.protocol.v20250618.Constants
            [~, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.protocol.v20250618.initialize(test.request("2025-06-18"));
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(httpMsg, 'OK');
            % A session-id header is appended; the value must be char, not string.
            test.verifyEqual(msgHeaders{1, 1}, char(Constants.SessionId));
            test.verifyClass(msgHeaders{1, 2}, "char");
            test.verifyNotEmpty(msgHeaders{1, 2});
        end

        % G6: negotiation. Each case checks the header as well as the body.

        function tSupportedVersionIsEchoed(test)
            test.verifyNegotiation("2025-06-18");
        end

        function tAliasIsNotEchoed(test)
            % 2024-11-05 is the HTTP+SSE transport, which this server does
            % not provide. Echoing it would claim that it does.
            test.verifyNegotiation("2024-11-05");
        end

        function tVersionWithoutInitializeIsNotEchoed(test)
            % 2026-07-28 is supported, but has no initialize: a handshake
            % cannot agree on it.
            test.verifyNegotiation("2026-07-28");
        end

        function tUnsupportedVersionIsNegotiatedNotRefused(test)
            % Negotiation is not an error path: answer with a version we
            % support, over 200.
            [~, httpCode] = prodserver.mcp.protocol.v20250618.initialize( ...
                test.request("1999-01-01"));
            test.verifyEqual(httpCode, 200);
            test.verifyNegotiation("1999-01-01");
        end

        function tMissingProtocolVersionIsInvalidParams(test)
            jrpc.jsonrpc = "2.0";
            jrpc.id = 7;
            jrpc.params = struct();
            test.verifyError(@() prodserver.mcp.protocol.v20250618.initialize(jrpc), ...
                "prodserver:mcp:InvalidParams");
        end

        function tMissingParamsIsInvalidParams(test)
            % XD1: confirmed live as a 500.
            jrpc.jsonrpc = "2.0";
            jrpc.id = 7;
            test.verifyError(@() prodserver.mcp.protocol.v20250618.initialize(jrpc), ...
                "prodserver:mcp:InvalidParams");
        end

        function tNonTextProtocolVersionIsInvalidParams(test)
            % XD1: guard the type, not just the presence.
            for v = {7, {"2025-06-18"}, ["2025-06-18" "2024-11-05"], struct('v',1)}
                test.verifyError(@() prodserver.mcp.protocol.v20250618.initialize( ...
                    test.request(v{1})), "prodserver:mcp:InvalidParams");
            end
        end

        % XD20: title is the archive name.

        function tTitleIsArchiveName(test)
            result = prodserver.mcp.protocol.v20250618.initialize( ...
                test.request("2025-06-18"), test.Archive);
            test.verifyEqual(result.result.serverInfo.title, test.Archive);
        end

        function tNoTitleWithoutArchiveName(test)
            % No path, no name: omit title rather than invent one.
            result = prodserver.mcp.protocol.v20250618.initialize( ...
                test.request("2025-06-18"));
            test.verifyFalse(isfield(result.result.serverInfo, "title"));
        end

        function tNoTitleFor2024Client(test)
            % Keyed on the requested version: the negotiated one is later.
            result = prodserver.mcp.protocol.v20250618.initialize( ...
                test.request("2024-11-05"), test.Archive);
            test.verifyEqual(result.result.protocolVersion, test.Negotiated);
            test.verifyFalse(isfield(result.result.serverInfo, "title"));
        end

        % End to end, through mcpHandler.

        function tEndToEndHeadersAgreeWithBody(test)
            % ND4: the header used to copy the request's version unnegotiated
            % (and not as char), so it said 2024-11-05 while the body said
            % 2025-06-18.
            %
            % The unsupported version goes in the body only: in a header it
            % is refused with 400 at resolution, before initialize runs
            % (tVersionResolution).
            import prodserver.mcp.MCPConstants
            cases = {"2025-06-18", {MCPConstants.ProtocolVersion, '2025-06-18'}
                     "2024-11-05", {MCPConstants.ProtocolVersion, '2024-11-05'}
                     "1999-01-01", cell(0,2)};
            for k = 1:size(cases, 1)
                v = cases{k,1};
                response = test.post(v, cases{k,2});
                test.verifyEqual(response.HttpCode, 200, v);
                decoded = prodserver.mcp.internal.decodeBody(response);
                test.verifyEqual(string(decoded.result.protocolVersion), ...
                    test.Negotiated, v);
                test.verifyVersionHeader(response.Headers, test.Negotiated);
            end
        end

        function tEndToEndOneSessionId(test)
            % ND3: an initialize carrying a session id got two -- the echo
            % and the newly minted one. The minted one replaces the echo.
            import prodserver.mcp.protocol.v20250618.Constants
            stale = 'stale-session-id';
            response = test.post("2025-06-18", {Constants.SessionId, stale});
            test.verifyEqual(response.HttpCode, 200);
            rows = strcmpi(response.Headers(:,1), Constants.SessionId);
            test.assertEqual(nnz(rows), 1, ...
                "An initialize response carries exactly one session id");
            test.verifyNotEqual(response.Headers{rows,2}, stale, ...
                "The session id is the minted one, not the request's");
        end

        function tEndToEndTitleIsArchiveName(test)
            response = test.post("2025-06-18");
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.verifyEqual(string(decoded.result.serverInfo.title), test.Archive);
        end

        function tEndToEndNonTextVersionIsInvalidParams(test)
            % -32602 over 200, the 2025-06-18 mapping for InvalidParams --
            % not the -32603/500 string() used to raise. Nor does a failed
            % initialize hand out a session.
            import prodserver.mcp.protocol.v20250618.Constants
            response = test.post(7);
            test.verifyEqual(response.HttpCode, 200, ...
                native2unicode(response.Body, "UTF-8"));
            decoded = prodserver.mcp.internal.decodeBody(response);
            test.verifyEqual(decoded.error.code, ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
            test.verifyEqual(decoded.id, 7);
            test.verifyFalse(any(strcmpi(response.Headers(:,1), ...
                Constants.SessionId)));
        end

    end

end
