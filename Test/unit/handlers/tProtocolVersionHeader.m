classdef tProtocolVersionHeader < prodserver.mcp.test.base.MCPHandlerBase
% The MCP-Protocol-Version header gate.
%
% The header used to be read and discarded, so the server silently accepted
% requests shaped by protocol revisions it does not implement. This server
% implements exactly one revision, MCPConstants.protocolVersion, so any other
% named value is 400 Bad Request.
%
% An ABSENT header is permitted, and that asymmetry is deliberate: the spec
% allows a client that has not yet negotiated to omit it, and this framework's
% own client omits it on initialize, notifications/initialized, */list and
% DELETE, sending it only from the tool-call and resource-read paths. Requiring
% it would break the framework against itself.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % Real revisions this server does not implement, plus a value that is
        % not a revision at all.
        rejectedVersion = {'2024-11-05', '2025-03-26', '2026-01-01', 'latest'};
    end

    methods (TestClassSetup)

        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture

            test.applyFixture(prodserver.mcp.test.mixin.RequireExamples());
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));

            test.fcnNames = "primeSequence";
            test.toolNames = "primeSequence";
            defineTools(test,test.fcnNames,test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.JSON);
        end
    end

    methods

        function response = listTools(test, version)
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, protocolVersion=version));
        end
    end

    methods (Test)

        function tAbsentHeaderPermitted(test)
            response = test.listTools("omit");
            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
        end

        function tSupportedVersionAccepted(test)
            response = test.listTools( ...
                prodserver.mcp.MCPConstants.protocolVersion);
            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
        end

        function tUnsupportedVersionIsBadRequest(test, rejectedVersion)
            response = test.listTools(rejectedVersion);
            test.verifyEqual(response.HttpCode, 400);
        end

        function tRejectionCarriesNoJsonRpcBody(test, rejectedVersion)
        % The version gate is a transport-level refusal: the request never
        % reached the JSON-RPC layer, so there is no JSON-RPC error to report.
            response = test.listTools(rejectedVersion);
            test.verifyEmpty(response.Body);
            test.verifyConformantResponse(response);
        end

        function tVersionGateRunsBeforeDecoding(test)
        % A body that could never be parsed must still be refused with 400 for
        % the version, not 200 with a -32700: the server declined to process
        % the request at all, so it did not look at the body.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", "{ not json", ...
                    protocolVersion="2025-03-26"));
            test.verifyEqual(response.HttpCode, 400);
            test.verifyEmpty(response.Body);
        end

        function tSupportedResponseReportsVersion(test)
        % A processed request is answered with the version actually in use, so
        % a client that omitted the header learns what it is talking to.
            response = test.listTools("omit");
            reported = prodserver.mcp.internal.getHeaderValue( ...
                prodserver.mcp.MCPConstants.ProtocolVersion, response.Headers);
            test.verifyEqual(string(reported), ...
                prodserver.mcp.MCPConstants.protocolVersion);
        end

    end
end
