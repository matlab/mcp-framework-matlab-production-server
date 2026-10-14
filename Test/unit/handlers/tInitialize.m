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

        function tAlwaysReportsSupportedVersion(test)
            % The lifecycle spec requires the server to answer with the version
            % it will actually use, not the one it was asked for. This server
            % implements exactly one, so every request gets the same answer --
            % including requests naming an older revision or nothing valid at
            % all. Echoing the client's string, as this used to, made the
            % server claim to speak protocols it does not implement.
            asked = ["2024-11-05" "2025-03-26" "not-a-version"];
            for v = asked
                result = prodserver.mcp.handler.initialize(test.request(v));
                test.verifyEqual(result.result.protocolVersion, ...
                    prodserver.mcp.MCPConstants.protocolVersion, ...
                    sprintf("initialize(%s) must still report the " + ...
                        "server's own version.", v));
            end
        end

        function tServerTitleIsVersionIndependent(test)
            % serverInfo.title is an optional display string, not part of
            % negotiation: it must not appear or disappear with the requested
            % version.
            asked = ["2024-11-05" "2025-03-26" "2025-06-18"];
            titles = strings(1,numel(asked));
            for k = 1:numel(asked)
                r = prodserver.mcp.handler.initialize(test.request(asked(k)));
                test.assertTrue(isfield(r.result.serverInfo,"title"), ...
                    sprintf("serverInfo.title missing for %s.", asked(k)));
                titles(k) = string(r.result.serverInfo.title);
            end
            test.verifyEqual(numel(unique(titles)), 1, ...
                "serverInfo.title must not vary with the requested version.");
            % Not a development-stage placeholder.
            test.verifyFalse(contains(titles(1),"Prototype", ...
                IgnoreCase=true));
        end

        function tMissingProtocolVersionIsBadParams(test)
            % protocolVersion is required by the initialize schema. Absent, it
            % is bad params -- not an indexing failure reported as an internal
            % server fault.
            jrpc.jsonrpc = "2.0";
            jrpc.id = 7;
            jrpc.params = struct();
            test.verifyError(@()prodserver.mcp.handler.initialize(jrpc), ...
                "prodserver:mcp:MissingParams");
        end

    end

end
