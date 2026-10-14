classdef tProtocolErrors < prodserver.mcp.test.base.MCPHandlerBase
% Lock down the JSON-RPC error code, and the HTTP status that carries it, for
% every class of malformed or unsupported request.
%
% The defect this file exists to prevent: mapErrorCode once recognized only a
% handful of framework identifiers, so a parse error, a missing method, a batch
% request and a missing tools/call name all collapsed to -32603 Internal Error
% over HTTP 500. A client could not tell "I sent bad JSON" from "the server is
% broken". Protocol-level errors belong in the body over HTTP 200; only a
% genuine internal fault is a 500.

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

        function tMalformedJsonIsParseError(test)
        % -32700. Unterminated object: jsondecode throws a MATLAB:json:*
        % identifier, which must not surface as an internal fault.
            response = test.post('{ "jsonrpc": "2.0", "id": 1, "method" ');
            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorParseError);
        end

        function tBareJsonValueIsInvalidRequest(test)
        % Issue #90. A bare number, string, boolean or null is valid JSON that
        % is not a request object, which JSON-RPC 2.0 calls an invalid request.
        % These used to get -32700, telling the client its JSON was malformed
        % when it was not. null and "" matter most: they decode to an empty
        % value, the same as an empty body, which is still a parse error.
            for body = ["42" """hello""" "true" "null" """"""]
                response = test.post(body);
                test.verifyErrorCode(response, ...
                    prodserver.mcp.MCPConstants.ErrorInvalidRequest, 200);
                jrpc = test.responseBody(response);
                test.verifyEmpty(jrpc.id, ...
                    "A bare value carries no id, so the reply id is null: " + body);
            end
        end

        function tEmptyObjectIsInvalidRequest(test)
        % {} is an object with nothing in it: valid JSON, invalid request.
            test.verifyErrorCode(test.post('{}'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tEmptyBodyIsParseError(test)
        % No JSON value at all, so nothing was parsed. Whitespace alone is the
        % same: JSON whitespace separates values and is not one.
            test.verifyErrorCode(test.post(''), ...
                prodserver.mcp.MCPConstants.ErrorParseError);
            test.verifyErrorCode(test.post(sprintf(' \r\n\t ')), ...
                prodserver.mcp.MCPConstants.ErrorParseError);
        end

        function tAbsentContentTypeIsNotAParseError(test)
        % A header the client did not send is a question it did not answer, not
        % a wrong answer. decodeBody compared the Content-Type against a string
        % literal, and getHeaderValue answers [] -- a 0x0 double -- for an
        % absent header, so the comparison itself raised. mcpHandler caught that
        % and rethrew it as -32700 "request body is not valid JSON", pointing
        % the client at a body that was perfectly good and saying nothing about
        % the header that was actually missing.
        %
        % JSON is the only request body this transport accepts, so an unstated
        % type is read as the one type there is.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", ...
                    '{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }', ...
                    contentType=""));

            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
            jrpc = test.responseBody(response);
            test.verifyFalse(isfield(jrpc,"error"), sprintf( ...
                "Omitting Content-Type must not be reported as an error: %s", ...
                jsonencode(jrpc)));
            test.verifyTrue(isfield(jrpc,"result"), ...
                "The request must be processed normally");
        end

        function tAbsentContentTypeStillDetectsRealParseErrors(test)
        % The permissive read of an absent Content-Type must not become a
        % blanket excuse: a body that genuinely is not JSON is still -32700,
        % and now for the right reason.
            response = prodserver.mcp.internal.mcpHandler( ...
                test.rawRequest("POST", '{ not json at all ', contentType=""));
            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorParseError);
        end

        function tUnparseableErrorReportsNullId(test)
        % There is no id to report when the body never parsed, and JSON-RPC
        % requires null in that case. "id" omitted entirely, or a non-numeric
        % placeholder, leaves a strict client unable to correlate the reply.
            response = test.post('{ not json at all ');
            jrpc = test.responseBody(response);
            test.assertTrue(isfield(jrpc,"id"));
            test.verifyEmpty(jrpc.id, "An unknown id must encode as null");
            test.verifyEqual(string(jrpc.jsonrpc), "2.0");
        end

        function tMissingJsonrpcIsInvalidRequest(test)
            test.verifyErrorCode( ...
                test.post('{ "id": 1, "method": "tools/list" }'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tWrongJsonrpcVersionIsInvalidRequest(test)
            test.verifyErrorCode( ...
                test.post('{ "jsonrpc": "1.0", "id": 1, "method": "tools/list" }'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tMissingMethodIsInvalidRequest(test)
            test.verifyErrorCode( ...
                test.post('{ "jsonrpc": "2.0", "id": 1, "params": {} }'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tEmptyMethodIsInvalidRequest(test)
            test.verifyErrorCode( ...
                test.post('{ "jsonrpc": "2.0", "id": 1, "method": "" }'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tBatchIsInvalidRequest(test)
        % This server handles one request per HTTP POST. A batch array decodes
        % two different ways and both must be refused: members with identical
        % field sets become a non-scalar struct array, members with differing
        % field sets -- a request mixed with a notification, the common real
        % case -- become a cell array. Before this check the struct-array form
        % silently answered only the first member.
            uniform = ['[{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" },' ...
                       ' { "jsonrpc": "2.0", "id": 2, "method": "tools/list" }]'];
            ragged  = ['[{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" },' ...
                       ' { "jsonrpc": "2.0", "method": "notifications/initialized" }]'];
            test.verifyErrorCode(test.post(uniform), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
            test.verifyErrorCode(test.post(ragged), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tBatchOfOneIsInvalidRequest(test)
        % Issue #89. jsondecode returns the same scalar struct for [{...}] as
        % for {...}, so a batch of one used to run as a single request and
        % answer with a bare object a batch-aware client did not ask for. The
        % reply id is null: the id inside belongs to a member, not to the
        % request that was refused.
            response = test.post('[{ "jsonrpc": "2.0", "id": 6, "method": "ping" }]');
            test.verifyErrorCode(response, ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
            jrpc = test.responseBody(response);
            test.verifyEmpty(jrpc.id, "A refused batch must reply with id null");
        end

        function tBatchOfOneDoesNotRunTheTool(test)
        % The serious half of issue #89: a tools/call wrapped in a one-element
        % batch ran the tool. tools/call emits the per-tool _Call metric once
        % it has resolved the tool, so its absence shows the call never got
        % that far. The unwrapped request is the positive control: without it,
        % a renamed metric would make this test pass vacuously.
            import prodserver.mcp.MCPConstants

            call = ['{ "jsonrpc": "2.0", "id": 9, "method": "tools/call", ' ...
                    '"params": { "name": "primeSequence", ' ...
                    '"arguments": { "n": 5, "type": "Mersenne" } } }'];
            toolMetric = MCPConstants.MCPMetricPrefix + "primeSequence" + ...
                MCPConstants.MCPToolCallSuffix;

            output = evalc("response = test.post(call);"); %#ok<NASGU>
            test.assertTrue(contains(output, toolMetric), ...
                "Control: an unwrapped tools/call must emit " + toolMetric);

            output = evalc("response = test.post(['[' call ']']);");
            test.verifyFalse(contains(output, toolMetric), ...
                "A tools/call inside a batch of one must not reach the tool");
            test.verifyErrorCode(response, MCPConstants.ErrorInvalidRequest);
        end

        function tBatchOfOneWithLeadingWhitespaceIsInvalidRequest(test)
        % JSON allows whitespace before the array. The batch check looks at
        % the first byte that is not whitespace, not the first byte.
            body = sprintf(' \r\n\t[{ "jsonrpc": "2.0", "id": 1, "method": "ping" }]');
            test.verifyErrorCode(test.post(body), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tNotificationBatchOfOneIsInvalidRequest(test)
        % A batch is refused whatever it contains, as a batch of two is. The
        % refusal is a reply to the POST, so a batch holding one notification
        % gets -32600 rather than the 202 the bare notification would get.
            test.verifyErrorCode(test.post( ...
                '[{ "jsonrpc": "2.0", "method": "notifications/initialized" }]'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tEmptyBatchIsInvalidRequest(test)
        % JSON-RPC 2.0 names an empty array as an invalid request. It used to
        % decode to [] and be reported as a -32700 parse error.
            test.verifyErrorCode(test.post('[]'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidRequest);
        end

        function tArrayInsideObjectIsNotBatch(test)
        % Only a top-level array is a batch. Arrays nested in the request
        % object, as tool arguments often are, must not trip the check.
            response = test.post( ...
                '{ "jsonrpc": "2.0", "id": 1, "method": "ping", "params": { "x": [1, 2] } }');
            test.verifyEqual(response.HttpCode, 200);
            jrpc = test.responseBody(response);
            test.verifyTrue(isfield(jrpc,"result"), "A ping must succeed");
        end

        function tUnknownMethodIsMethodNotFound(test)
            test.verifyErrorCode( ...
                test.post('{ "jsonrpc": "2.0", "id": 1, "method": "no/such/method" }'), ...
                prodserver.mcp.MCPConstants.ErrorMethodNotFound);
        end

        function tUnadvertisedListMethodsAreMethodNotFound(test)
        % prompts/list and resources/templates/list are capabilities this
        % server does not advertise. A generic */list fallback used to answer
        % them with 204 No Content -- and a body, which the status forbids.
        % A client asking for them has named a method that does not exist.
            for mth = ["prompts/list" "resources/templates/list"]
                body = sprintf('{ "jsonrpc": "2.0", "id": 1, "method": "%s" }', mth);
                test.verifyErrorCode(test.post(body), ...
                    prodserver.mcp.MCPConstants.ErrorMethodNotFound);
            end
        end

        function tToolCallWithoutParamsIsInvalidParams(test)
            test.verifyErrorCode( ...
                test.post('{ "jsonrpc": "2.0", "id": 1, "method": "tools/call" }'), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tToolCallWithoutNameIsInvalidParams(test)
            test.verifyErrorCode( ...
                test.post(['{ "jsonrpc": "2.0", "id": 1, "method": "tools/call", ' ...
                           '"params": { "arguments": {} } }']), ...
                prodserver.mcp.MCPConstants.ErrorInvalidParams);
        end

        function tErrorsEchoTheRequestId(test)
        % A protocol error still belongs to a request. Reporting the wrong id,
        % or none, breaks correlation on a pipelined client.
            response = test.post( ...
                '{ "jsonrpc": "2.0", "id": 4242, "method": "no/such/method" }');
            jrpc = test.responseBody(response);
            test.verifyEqual(jrpc.id, 4242);
        end

        function tExplicitNullIdIsNotTreatedAsNotification(test)
        % jsondecode turns "id": null into an empty double and isfield still
        % reports it present, so this is a request with a null id, not a
        % notification: it gets a reply. The id must re-encode as null -- an
        % empty value would emit "id":[], which is not valid JSON-RPC.
            response = test.post( ...
                '{ "jsonrpc": "2.0", "id": null, "method": "no/such/method" }');
            test.verifyEqual(response.HttpCode, 200);
            test.verifyConformantResponse(response);
            txt = native2unicode(response.Body,"UTF-8");
            test.verifyTrue(contains(txt,'"id":null'), ...
                "A null id must round-trip as null, not as []");
        end

    end
end
