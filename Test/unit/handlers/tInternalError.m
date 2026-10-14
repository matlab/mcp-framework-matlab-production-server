classdef tInternalError < prodserver.mcp.test.base.MCPHandlerBase
% HTTP 500 is reserved for a genuine internal fault, and it must still happen.
%
% The conformance work moved every client-level JSON-RPC error off HTTP 500 and
% onto HTTP 200, because the transport had succeeded and the error belonged in
% the body. That left the 500 branch of errorHttpStatus asserted nowhere: every
% reference to 500 or -32603 in Test/unit was a verifyNotEqual or a comment, so
% the branch could have been deleted outright and the suite would have stayed
% green. A conformance suite that only pins what must *not* return 500 does not
% pin what must.
%
% The difficulty is that no well-formed request should ever produce a 500 -- that
% is the whole point of the status -- so the fault has to be injected. The
% injection used here is a realistic one rather than a contrivance: a deployed
% archive whose metadata is internally inconsistent, advertising a tool in its
% tools list that has no matching entry in its signatures. The handler resolves
% the tool by name, then indexes the signature that is not there. Nothing about
% the request is wrong, nothing the client can change will help, and "the server
% is broken" is the only honest answer -- which is exactly what 500 means.
%
% The client half of this contract is already covered: requireSuccess surfacing
% the detail from a 500 that carries a JSON-RPC error object is asserted by
% tRequireSuccess/tServerErrorJsonRpcError.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        % Identifiers that mapErrorCode must NOT recognize. These are ordinary
        % MATLAB faults of the kind a bug in a handler actually raises; none of
        % them says anything about the client's request, so none may be reported
        % as a client-level error.
        UnmappedIdentifiers = [ ...
            "MATLAB:nonExistentField", ...
            "MATLAB:badsubscript", ...
            "MATLAB:UndefinedFunction", ...
            "MATLAB:structRefFromNonStruct", ...
            "prodserver:mcp:SomeFutureFailureNobodyMapped"];
    end

    methods (TestClassSetup)

        function prepareBrokenArchive(test)
        % Build a definition that is valid in every respect except that the
        % tool it advertises has no signature. Deliberately not routed through
        % defineTools, which exists to produce consistent definitions.
            import prodserver.mcp.MCPConstants

            rtt = test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;

            test.fcnNames = "toyZeroInputs";
            test.toolNames = "toyZeroInputs";

            definition = prodserver.mcp.internal.defineForMCP( ...
                test.toolNames, test.fcnNames, ...
                encoding=prodserver.mcp.WireEncoding.JSON);

            % Assert the precondition before breaking it, so that a future
            % change to defineForMCP's output shape fails here with a readable
            % message rather than silently making the injection a no-op.
            test.assertTrue(isfield(definition.signatures,"toyZeroInputs"), ...
                "Expected a signature for the tool about to be orphaned");
            definition.signatures = ...
                rmfield(definition.signatures,"toyZeroInputs");

            test.definitionFile = fullfile(test.tempFolder, ...
                MCPConstants.DefinitionFile);
            def.(MCPConstants.DefinitionVariable) = definition;
            def.(MCPConstants.ResourceVariable) = ...
                prodserver.mcp.internal.resourceDefinition( ...
                    {MCPConstants.WireEncodingResource});
            save(test.definitionFile,"-struct","def");

            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods (TestClassTeardown)

        function dropBrokenDefinition(~)
        % The services cache is keyed on the CTF root, which is not unique
        % between test classes running in one MATLAB session. Leaving a
        % deliberately corrupt definition in appdata would break whatever runs
        % next, in a way that would look nothing like this file's fault.
            prodserver.mcp.handler.toolServices(action="clear");
        end
    end

    methods (Test)

        function tGenuineFaultIsInternalError(test)
        % The end-to-end case: a well-formed request a broken server cannot
        % honour. HTTP 500 and -32603 must agree, which is the invariant the
        % whole conformance effort is about.
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/call", ' ...
                    '"params": { "name": "toyZeroInputs" } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorInternalError, 500);
            test.verifyEqual(string(response.HttpMessage), ...
                "Internal Server Error");
        end

        function tInternalErrorStillReportsTheRequestId(test)
        % An internal fault is still a reply to a specific request. Losing the
        % id would leave a client unable to match the failure to what it sent,
        % which matters most precisely when the server is misbehaving.
            body = ['{ "jsonrpc": "2.0", "id": 4242, "method": "tools/call", ' ...
                    '"params": { "name": "toyZeroInputs" } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            jrpc = test.responseBody(response);
            test.verifyEqual(jrpc.id, 4242);
            test.verifyNotEmpty(jrpc.error.message, ...
                "An internal error must say something about itself");
        end

        function tUnmappedIdentifierIsInternalError(test)
        % mapErrorCode's default branch. An identifier nobody has classified is
        % an internal fault by definition: guessing a client-level code for it
        % would tell the client its request was at fault when it was not.
            for id = test.UnmappedIdentifiers
                ex = MException(id, "injected");
                code = prodserver.mcp.handler.internal.mapErrorCode(ex);
                test.verifyEqual(code, ...
                    prodserver.mcp.MCPConstants.ErrorInternalError, ...
                    "Identifier '" + id + "' must map to -32603");
            end
        end

        function tOnlyInternalErrorMapsToFiveHundred(test)
        % The load-bearing assertion. Before this test the 500 branch of
        % errorHttpStatus could be deleted with the suite staying green; now
        % deleting it fails here, and widening it to swallow a client-level
        % code fails here too.
            import prodserver.mcp.MCPConstants

            [httpCode, httpMsg] = ...
                prodserver.mcp.handler.internal.errorHttpStatus( ...
                    MCPConstants.ErrorInternalError);
            test.verifyEqual(httpCode, 500);
            test.verifyEqual(string(httpMsg), "Internal Server Error");

            clientErrors = [ ...
                MCPConstants.ErrorParseError, ...
                MCPConstants.ErrorInvalidRequest, ...
                MCPConstants.ErrorMethodNotFound, ...
                MCPConstants.ErrorInvalidParams, ...
                MCPConstants.ErrorResourceNotFound];
            for code = clientErrors
                [httpCode, httpMsg] = ...
                    prodserver.mcp.handler.internal.errorHttpStatus(code);
                test.verifyEqual(httpCode, 200, ...
                    sprintf("JSON-RPC %d is a client-level error and " + ...
                        "belongs on HTTP 200", code));
                test.verifyEqual(string(httpMsg), "OK");
            end
        end

        function tUnclassifiedCodeIsTreatedAsInternal(test)
        % errorHttpStatus is reached with whatever code mapErrorCode produced,
        % so its fallback has to be the safe one. A code it has never heard of
        % is a server fault, not a client fault: defaulting the other way would
        % report a broken server as a successful transport.
            [httpCode, ~] = ...
                prodserver.mcp.handler.internal.errorHttpStatus(-32099);
            test.verifyEqual(httpCode, 500);
        end
    end
end
