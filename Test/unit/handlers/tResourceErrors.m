classdef tResourceErrors < prodserver.mcp.test.base.MCPHandlerBase
% resources/read failure modes.
%
% The defect: a read of a URI this server does not host answered 204 No Content
% and then supplied a body anyway. That breaks the HTTP contract in both
% directions -- a 204 forbids a body, and a client that honours the status
% discards the explanation it was sent. MCP defines -32002 Resource not found
% for exactly this, carried in a body over HTTP 200.

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

        function response = post(test, body)
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));
        end
    end

    methods (Test)

        function tUnknownUriIsResourceNotFound(test)
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/read", ' ...
                    '"params": { "uri": "mcp://no/such/resource" } }'];
            test.verifyErrorCode(test.post(body), ...
                prodserver.mcp.MCPConstants.ErrorResourceNotFound);
        end

        function tUnknownUriIsNotNoContent(test)
        % The specific regression: a status that forbids a body, sent together
        % with a body, and with a result rather than an error in it.
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/read", ' ...
                    '"params": { "uri": "mcp://no/such/resource" } }'];
            response = test.post(body);

            test.verifyNotEqual(response.HttpCode, 204);
            test.verifyEqual(response.HttpCode, 200);
            jrpc = test.responseBody(response);
            test.verifyFalse(isfield(jrpc,"result"), ...
                "A not-found read reports an error, not a result");
        end

        function tResourceNotFoundIsNotAnInternalError(test)
        % -32002 is a client error: the client named a resource that does not
        % exist. Reporting HTTP 500 would tell the client the server is broken
        % and invite a retry that can never succeed.
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/read", ' ...
                    '"params": { "uri": "mcp://no/such/resource" } }'];
            response = test.post(body);

            test.verifyEqual(response.HttpCode, 200);
            jrpc = test.responseBody(response);
            test.verifyNotEqual(jrpc.error.code, ...
                prodserver.mcp.MCPConstants.ErrorInternalError);
        end

        function tMissingUriIsInvalidParams(test)
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "resources/read", ' ...
                    '"params": {} }'];
            test.verifyErrorCode(test.post(body), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tMissingParamsIsInvalidParams(test)
            body = '{ "jsonrpc": "2.0", "id": 1, "method": "resources/read" }';
            test.verifyErrorCode(test.post(body), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tKnownUriReads(test)
        % The contrast case: the resource this server does host still reads, so
        % the not-found path cannot be satisfied by failing every read.
            body = sprintf(['{ "jsonrpc": "2.0", "id": 1, ' ...
                '"method": "resources/read", "params": { "uri": "%s" } }'], ...
                prodserver.mcp.MCPConstants.WireEncodingResource.uri);
            response = test.post(body);

            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
            jrpc = test.responseBody(response);
            test.verifyTrue(isfield(jrpc,"result"));
            test.verifyFalse(isfield(jrpc,"error"));
        end

    end
end
