classdef tInitialize < matlab.unittest.TestCase
% Test prodserver.mcp.handler.initialize (handle the MCP initialize request:
% negotiate protocol version, advertise capabilities, mint a session id).

% Copyright 2026 The MathWorks, Inc.

    methods

        function jrpc = request(~, protocolVersion)
            jrpc.jsonrpc = "2.0";
            jrpc.id = 7;
            jrpc.params.protocolVersion = protocolVersion;
        end

    end

    methods (Test)

        function tNegotiatesProtocolAndIdentity(test)
            result = prodserver.mcp.handler.initialize(test.request("2025-06-18"));
            test.verifyEqual(result.id, 7);
            test.verifyEqual(result.jsonrpc, "2.0");
            r = result.result;
            test.verifyEqual(r.protocolVersion, "2025-06-18");
            test.verifyEqual(r.serverInfo.name, "MATLAB Production Server");
            test.verifyEqual(r.serverInfo.version, "1.0.0");
        end

        function tAdvertisesCapabilities(test)
            result = prodserver.mcp.handler.initialize(test.request("2025-06-18"));
            r = result.result;
            test.verifyTrue(r.capabilities.tools.listChanged);
            test.verifyTrue(r.capabilities.resources.listChanged);
        end

        function tSessionIdHeader(test)
            import prodserver.mcp.MCPConstants
            [~, httpCode, httpMsg, msgHeaders] = ...
                prodserver.mcp.handler.initialize(test.request("2025-06-18"));
            test.verifyEqual(httpCode, 200);
            test.verifyEqual(httpMsg, 'OK');
            % A session-id header is appended; the value must be char, not string.
            test.verifyEqual(msgHeaders{1, 1}, char(MCPConstants.SessionId));
            test.verifyClass(msgHeaders{1, 2}, "char");
            test.verifyNotEmpty(msgHeaders{1, 2});
        end

        function tPrototypeTitleForNon2024(test)
            % Newer protocols get a prototype title; the 2024 protocol does not.
            newer = prodserver.mcp.handler.initialize(test.request("2025-06-18"));
            test.verifyEqual(newer.result.serverInfo.title, "Prototype MCP Server");
            old = prodserver.mcp.handler.initialize(test.request("2024-11-05"));
            test.verifyFalse(isfield(old.result.serverInfo, "title"));
        end

    end

end
