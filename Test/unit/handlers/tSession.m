classdef tSession < prodserver.mcp.test.base.MCPHandlerBase
% The Mcp-Session-Id gate.
%
% initialize is where a session comes from, so it is exempt. Every other
% request must carry a session id, and one that is absent or blank is 400 Bad
% Request -- a transport-level refusal, carrying no JSON-RPC body.
%
% The check is deliberately SYNTACTIC ONLY: any non-blank value is accepted and
% nothing is ever looked up. MATLAB Production Server dispatches successive
% requests to arbitrary workers in a pool and this framework establishes no
% affinity, so appdata and persistent are per-worker. A real session registry
% would let initialize succeed on worker A and the following tools/call 404 on
% worker B, which is strictly worse than not enforcing at all. The consequence
% -- that a terminated session's id keeps working, where the spec says 404 --
% is accepted knowingly.

% Copyright 2026 The MathWorks, Inc.

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

        function response = listTools(test, session)
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }';
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, session=session));
        end
    end

    methods (Test)

        function tInitializeNeedsNoSessionAndMintsOne(test)
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "initialize", ' ...
                    '"params": { "protocolVersion": "2025-06-18" } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body, session="omit"));

            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);

            session = prodserver.mcp.internal.getHeaderValue( ...
                prodserver.mcp.MCPConstants.SessionId, response.Headers);
            test.assertNotEmpty(session, ...
                "initialize must return a session id");
            test.verifyGreaterThan(strlength(strtrim(string(session))), 0);
        end

        function tMissingSessionIsBadRequest(test)
            response = test.listTools("omit");

            test.verifyEqual(response.HttpCode, 400);
            test.verifyEmpty(response.Body, ...
                "A transport-level refusal carries no JSON-RPC body");
            test.verifyConformantResponse(response);
        end

        function tBlankSessionIsBadRequest(test)
        % A header present but empty, and one that is only whitespace, are both
        % the same failure as sending none: there is no id there.
            for value = ["", " ", sprintf("\t")]
                response = test.listTools(value);
                test.verifyEqual(response.HttpCode, 400, ...
                    sprintf("Blank session '%s' must be refused", value));
                test.verifyEmpty(response.Body);
            end
        end

        function tUuidSessionAccepted(test)
            response = test.listTools(string(matlab.lang.internal.uuid));
            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
        end

        function tAnyNonBlankSessionAccepted(test)
        % Guards against anyone later tightening this into the RFC 7329
        % "SID:<type>:<realm>:<uuid>" form that prodserver.mcp.validation
        % .mustBeSessionID and Constants.SessionIDPattern describe. That form
        % belongs to the io URI-marshalling layer, not to MCP: the ids on the
        % wire are bare UUIDs, and the integration fixtures under
        % Test/integration/client use the literal "alpha". Applying that
        % validator here would reject every real request.
            for value = ["alpha", "1", "not-a-uuid-at-all"]
                response = test.listTools(value);
                test.verifyEqual(response.HttpCode, 200, ...
                    sprintf("Session '%s' must be accepted: the check is " + ...
                        "syntactic and blank-only", value));
            end
        end

        function tSessionEchoedExactlyOnce(test)
        % There are two places a session id can reach the response headers --
        % the request echo and a handler's own msgHeaders -- so a duplicate is
        % a live hazard, not a hypothetical one.
            session = string(matlab.lang.internal.uuid);
            response = test.listTools(session);

            names = string(response.Headers(:,1));
            rows = strcmpi(names, string(prodserver.mcp.MCPConstants.SessionId));
            test.verifyEqual(nnz(rows), 1);
            test.verifyEqual(string(response.Headers{rows,2}), session);
        end

        function tDeleteWithSessionTerminates(test)
            session = char(matlab.lang.internal.uuid);
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("DELETE", "", session=string(session), ...
                    contentType=""));

            test.verifyEqual(response.HttpCode, 204);
            test.verifyEmpty(response.Body);
            test.verifyConformantResponse(response);
        end

        function tDeleteWithoutSessionIsBadRequest(test)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("DELETE", "", session="omit", ...
                    contentType=""));

            test.verifyEqual(response.HttpCode, 400);
            test.verifyEmpty(response.Body);
            test.verifyConformantResponse(response);
        end

    end
end
