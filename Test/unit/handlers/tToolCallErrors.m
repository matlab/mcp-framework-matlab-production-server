classdef tToolCallErrors < prodserver.mcp.test.base.MCPHandlerBase
% tools/call failure modes, and the line between the two kinds of failure.
%
% MCP splits tool failures in two, and the split is the whole point of this
% file. A PROTOCOL error -- an unknown tool, missing or bad params -- is a
% JSON-RPC error member. A tool-EXECUTION error -- the tool ran and threw -- is
% result.isError over HTTP 200, because both the transport and the protocol
% succeeded. Collapsing the second into the first is an easy refactor to make
% and it makes every tool failure look like a broken server.
%
% The specific defect here: the required-argument check tested whether the
% intersection of required and supplied names was empty, which only fires when
% EVERY required argument is missing. A call supplying some but not all of them
% fell through to an unguarded struct index outside the try block, reported as
% -32603 Internal Error over HTTP 500 rather than -32602 Invalid params.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)

        function prepareTools(test)
            rtt = test.applyFixture( ...
                prodserver.mcp.test.mixin.RequireToyTools());
            test.toolsFolder = rtt.toolFolder;

            test.fcnNames = ["toyScalarTwo" "toyScalarOptions"];
            test.toolNames = test.fcnNames;
            defineTools(test,test.fcnNames,test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.JSON);
        end
    end

    methods

        function response = callTool(test, name, argumentsJson)
            arguments
                test
                name (1,1) string
                argumentsJson (1,1) string = "{}"
            end

            body = sprintf(['{ "jsonrpc": "2.0", "id": 1, ' ...
                '"method": "tools/call", "params": ' ...
                '{ "name": "%s", "arguments": %s } }'], name, argumentsJson);
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));
        end
    end

    methods (Test)

        function tUnknownToolIsInvalidParams(test)
        % The method tools/call exists; the tool named in its params does not.
        % That makes it bad params, not an unknown method.
            test.verifyErrorCode(test.callTool("noSuchToolAnywhere"), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tAllRequiredArgumentsMissingIsInvalidParams(test)
            test.verifyErrorCode(test.callTool("toyScalarTwo","{}"), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tSomeRequiredArgumentsMissingIsInvalidParams(test)
        % The regression test. toyScalarTwo requires s and n; supplying only s
        % used to pass the all-or-nothing check and then fail on an index.
            test.verifyErrorCode( ...
                test.callTool("toyScalarTwo",'{ "s": "abcdef" }'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tSomeRequiredArgumentsMissingIsNotServerFault(test)
        % Stated separately from the code check because this is the symptom a
        % user actually sees: a 500 invites a retry, and tells them the server
        % is broken when their request was.
            response = test.callTool("toyScalarTwo",'{ "s": "abcdef" }');
            test.verifyEqual(response.HttpCode, 200);
            test.verifyNotEqual(response.HttpCode, 500);
        end

        function tMissingArgumentsNamedInMessage(test)
        % The message used to print the required list in the "received"
        % position too, so it read as though the client had sent exactly what
        % was required and been refused anyway. Required, received and missing
        % must be distinguishable.
            response = test.callTool("toyScalarTwo",'{ "s": "abcdef" }');
            jrpc = test.responseBody(response);
            msg = string(jrpc.error.message);

            test.verifyTrue(contains(msg,"toyScalarTwo"), ...
                "Message must name the tool");
            test.verifyTrue(contains(msg,"n"), ...
                "Message must name the missing argument");
            % "received 's'" and "requires 's,n'" are different strings: if
            % received were printed as the required list, the two would match.
            test.verifyFalse(count(msg,"s,n") > 1, ...
                "The required list must not be printed in the received " + ...
                "position as well");
        end

        function tMissingParamsNameIsInvalidParams(test)
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/call", ' ...
                    '"params": { "arguments": { "s": "abc" } } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));
            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tAbsentArgumentsReachesTheParamsCheck(test)
        % arguments is optional in the tools/call schema, so an absent one must
        % be read as "no arguments supplied" rather than failing to index a
        % field that is not there. toyScalarOptions requires year, so the
        % answer is still a params error -- but it must be THE params error,
        % reached by the normal path, not an indexing failure reported as an
        % internal fault over HTTP 500.
            body = ['{ "jsonrpc": "2.0", "id": 1, "method": "tools/call", ' ...
                    '"params": { "name": "toyScalarOptions" } }'];
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", body));

            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tRequiredOnlyCallSucceeds(test)
        % Supplying exactly the required arguments and no optional ones.
            response = test.callTool("toyScalarOptions",'{ "year": 1937 }');

            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
            jrpc = test.responseBody(response);
            test.assertTrue(isfield(jrpc,"result"));
            test.verifyFalse(isfield(jrpc.result,"isError"), ...
                sprintf("Tool reported an execution error: %s", ...
                    jsonencode(jrpc.result)));
            test.verifyTrue(contains( ...
                string(jrpc.result.structuredContent.report),"1937"));
        end

        function tOptionalArgumentsAreNotDropped(test)
        % Optional positional arguments were assembled using the
        % required-argument loop variable as a cursor. Supplying optional
        % arguments must actually deliver them to the tool.
        %
        % They are POSITIONAL, so they are supplied contiguously from the start
        % of the optional list: year, then mpg, then range.
            response = test.callTool("toyScalarOptions", ...
                '{ "year": 1937, "mpg": 9.5, "range": 2400 }');

            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
            jrpc = test.responseBody(response);
            test.assertTrue(isfield(jrpc,"result"));
            test.verifyFalse(isfield(jrpc.result,"isError"), ...
                sprintf("Tool reported an execution error: %s", ...
                    jsonencode(jrpc.result)));
            report = string(jrpc.result.structuredContent.report);
            test.verifyTrue(contains(report,"9.50"), ...
                "Optional argument mpg was dropped on the way to the tool");
            test.verifyTrue(contains(report,"2400"), ...
                "Optional argument range was dropped on the way to the tool");
        end

        function tExecutionErrorIsNotAProtocolError(test)
        % The other half of the split. "n": "ninetynine" arrives as a char
        % array, so toyScalarTwo's own (1,1) double validation rejects it --
        % the tool ran and failed. That is HTTP 200 with result.isError, and it
        % must carry NO JSON-RPC error member; otherwise a later refactor could
        % collapse every tool failure into a protocol failure and no client
        % would be able to tell a broken tool from a broken server.
            response = test.callTool("toyScalarTwo", ...
                '{ "s": "abcdef", "n": "ninetynine" }');

            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
            jrpc = test.responseBody(response);
            test.verifyFalse(isfield(jrpc,"error"), ...
                "A tool-execution failure is not a JSON-RPC error");
            test.assertTrue(isfield(jrpc,"result"));
            test.verifyTrue(jrpc.result.isError, ...
                "A failed tool must report isError");
            test.verifyNotEmpty(jrpc.result.content, ...
                "An isError result must explain itself in content");
        end

        function tRejectedInputNamesItsPosition(test)
        % Issue #91. The tool was called through feval, and an arguments block
        % that rejects an input inside feval counts the function name as
        % argument 1. The error named position 2 for toyScalarTwo's first
        % input and position 3 for its second. An LLM reads that text to fix
        % its call, so the position must be the one in the tool's signature.
            cases = { ...
                '{ "s": ["a", "b"], "n": 1 }',        "position 1"; ...
                '{ "s": "abcdef", "n": "ninetynine" }', "position 2"};
            for k = 1:height(cases)
                jrpc = test.responseBody(test.callTool("toyScalarTwo", cases{k,1}));
                test.assertTrue(isfield(jrpc,"result") && ...
                    isfield(jrpc.result,"isError"), ...
                    "Expected a tool-execution error for " + cases{k,1});
                text = string(jrpc.result.content(1).text);
                test.verifyTrue(contains(text, cases{k,2}), ...
                    "Expected " + cases{k,2} + " in: " + text);
            end
        end

        function tRejectedInputPositionOutsideDispatcher(test)
        % Issue #91 again, without mcpHandler in between. feval's miscount
        % depends on how its CALLER was reached: inside a function that was
        % itself invoked through feval, the inner feval counts correctly.
        % mcpHandler calls tools.call directly today, so the test above
        % catches a reversion to feval, but it would silently stop doing so
        % if the dispatcher ever invoked handlers through feval. Calling the
        % handler directly keeps the context that exposes the miscount.
            jrpc.jsonrpc = "2.0";
            jrpc.id = 1;
            jrpc.method = "tools/call";
            jrpc.params.name = "toyScalarTwo";

            % Shaped as jsondecode delivers them: a JSON string array is a
            % cellstr column, a JSON number array a double column.
            cases = {
                struct('s', {{'a';'b'}}, 'n', 1),  "position 1", "non-scalar s"
                struct('s', 'abc', 'n', [1;2]),    "position 2", "non-scalar n"
                };
            for k = 1:height(cases)
                jrpc.params.arguments = cases{k,1};
                result = prodserver.mcp.handler.tools.call(jrpc);
                test.assertTrue(isfield(result.result,'isError') && ...
                    logical(result.result.isError), cases{k,3});
                text = string(result.result.content{1}.text);
                test.verifyTrue(contains(text, cases{k,2}), ...
                    cases{k,3} + ": " + text);
            end
        end

    end
end
