classdef tToolsCallErrors < prodserver.mcp.test.base.MCPHandlerBase
% Error taxonomy for tools/call. A request-level problem -- an unknown
% tool, a missing 'name' -- is a JSON-RPC protocol error carrying -32602.
% Arguments that fail validation -- no 'arguments' object where inputs are
% required, a missing or unknown argument, a value the schema rejects -- are
% reported as each revision says: -32602 under 2025-06-18, a tool execution
% error (result.isError) under 2026-07-28. Either way the tool doesn't run.
% A tool that was found and ran and then failed is reported in band as
% result.isError over HTTP 200, so the model can read the message and
% correct its call.
%
% The HTTP status assertions are the point of this file. -32602 is
% deliberately overloaded: under 2026-07-28 the missing-_meta family must
% carry HTTP 400, while an unknown tool or bad arguments must stay 200. A
% test that asserts only the numeric code cannot tell the two apart, which
% is how the original defect survived.

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        InvalidParams = -32602;
    end

    methods (TestClassSetup)

        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture

            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));

            % toyScalarTwo has two required inputs; toyZeroInputs has none.
            % The pair is what separates "no arguments object" from "no
            % arguments object and none needed".
            % toyPositiveTwo has constraints MATLAB enforces but the schema
            % can't express; toyUnsized has an input with no declared size.
            test.fcnNames = ["toyScalarTwo","toyZeroInputs", ...
                "toyPositiveTwo","toyUnsized"];
            test.toolNames = test.fcnNames;

            defineTools(test,test.fcnNames,test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.JSON);
        end
    end

    methods

        function [response, decoded] = post(test, params)
        % POST a tools/call whose params are given as a MATLAB struct, so a
        % test can omit 'name' or 'arguments' entirely -- which createRequest
        % cannot express.
            import prodserver.mcp.MCPConstants

            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];

            body.jsonrpc = "2.0";
            body.id = 1;
            body.method = "tools/call";
            if ~isempty(params)
                body.params = params;
            end
            body = jsonencode(body);

            [req, body] = test.applyProtocol(req, body);

            reqT = req;
            reqT.Method = "POST";
            reqT.Path = "/toyScalarTwo/mcp";
            reqT.Headers = [reqT.Headers; ...
                {MCPConstants.ContentLength, numel(body)}];
            reqT.Body = unicode2native(body,"UTF-8");

            response = test.handle(reqT);
            decoded = prodserver.mcp.internal.decodeBody(response);
        end

        function verifyProtocolError(test, params, context)
        % A request-level failure: JSON-RPC error object, -32602, HTTP 200.
        % 200 because the request reached a live method on a live protocol;
        % only the missing-_meta family escalates to 400.
            [response, decoded] = test.post(params);
            test.verifyEqual(response.HttpCode, 200, ...
                context + ": status must stay 200");
            test.assertTrue(isfield(decoded,'error'), ...
                context + ": expected a JSON-RPC error object");
            test.verifyEqual(decoded.error.code, test.InvalidParams, ...
                context + ": expected -32602");
            test.verifyFalse(isfield(decoded,'result'), ...
                context + ": an error response must carry no result");
            test.verifyEqual(decoded.id, 1, ...
                context + ": the request id must be echoed");
        end

        function msg = verifyInputError(test, params, context)
        % Arguments that failed validation: -32602 under 2025-06-18; under
        % 2026-07-28 a tool execution error, so the model can correct its
        % call. Returns the message either way.
            if ~prodserver.mcp.protocol.inputErrorsAreToolErrors(test.protocol)
                test.verifyProtocolError(params, context);
                [~, decoded] = test.post(params);
                msg = string(decoded.error.message);
                return
            end
            [response, decoded] = test.post(params);
            test.verifyEqual(response.HttpCode, 200, context);
            test.verifyFalse(isfield(decoded,'error'), ...
                context + ": 2026-07-28 reports bad arguments in band");
            test.assertTrue(isfield(decoded,'result') && ...
                isfield(decoded.result,'isError') && ...
                logical(decoded.result.isError), ...
                context + ": expected result.isError");
            msg = string(decoded.result.content(1).text);
            test.verifyTrue(startsWith(msg, "Input validation error: "), ...
                context + ": " + msg);
            test.verifyFalse(isfield(decoded.result,'structuredContent'), ...
                context + ": the tool must not have run");
        end

        function verifyHeaderMismatch(test, params, context)
        % A required-header failure: -32020 over HTTP 400. Distinct from
        % verifyProtocolError, and deliberately not a relaxation of it --
        % the status and the code both differ, so a single assertion that
        % accepted either would stop testing the thing these tests are for.
            C = prodserver.mcp.protocol.v20260728.Constants;
            [response, decoded] = test.post(params);
            test.verifyEqual(response.HttpCode, 400, ...
                context + ": a missing required header is a 400");
            test.assertTrue(isfield(decoded,'error'), ...
                context + ": expected a JSON-RPC error object");
            test.verifyEqual(decoded.error.code, C.ErrorHeaderMismatch, ...
                context + ": expected -32020");
            test.verifyFalse(isfield(decoded,'result'), ...
                context + ": an error response must carry no result");
        end

    end

    methods (Test)

        function unknownTool(test)
            % Unknown tool is a request-level error, but NOT one of the
            % statuses 2026-07-28 escalates: it stays 200.
            p.name = "noSuchToolAnywhere";
            p.arguments = struct('s', "abc", 'n', 1);
            test.verifyProtocolError(p, "unknown tool");
        end

        function missingName(test)
            % Without the guard this reaches a raw field access and maps to
            % -32603/500, reporting a client mistake as a server fault.
            %
            % The two revisions answer differently, and both answers are
            % right. Under 2026-07-28 tools/call MUST carry an Mcp-Name
            % header mirroring params.name; a body with no name cannot
            % produce one, so the request fails on the missing header -- a
            % mandated -32020/400 -- before any handler reads the body. The
            % client is not at liberty to invent a header value to reach the
            % body error instead. Under 2025-06-18 there is no such header
            % and the body guard is what answers, with -32602/200.
            %
            % Forked rather than loosened: asserting "either" would leave
            % both revisions untested, and the 400 is the more specific
            % diagnosis of the two.
            p.arguments = struct('s', "abc", 'n', 1);
            if test.protocol == "2025-06-18"
                test.verifyProtocolError(p, "missing params.name");
            else
                test.verifyHeaderMismatch(p, ...
                    "missing params.name, so no Mcp-Name to send");
            end
        end

        function missingArgumentsWhenRequired(test)
            % toyScalarTwo declares two required inputs, so an absent
            % 'arguments' object is a malformed call, not a zero-arg call.
            p.name = "toyScalarTwo";
            test.verifyInputError(p, "missing params.arguments");
        end

        function nonStructArguments(test)
            % 'arguments' present but not a JSON object.
            p.name = "toyScalarTwo";
            p.arguments = "not an object";
            test.verifyInputError(p, "non-object params.arguments");
        end

        function partialArgumentsIsInvalidParams(test)
            % XD12: one of two required inputs. The old any-one-of test let
            % this through to a raw field access, and so to -32603/500.
            p.name = "toyScalarTwo";
            p.arguments = struct('s', "abc");
            msg = test.verifyInputError(p, "one required argument missing");

            % XD13: the message names what was received and what is
            % missing, not the required list twice.
            test.verifyTrue(contains(msg, "requires inputs 's,n'"), msg);
            test.verifyTrue(contains(msg, "received 's'"), msg);
            test.verifyTrue(contains(msg, "Missing: 'n'"), msg);
        end

        function emptyArgumentsWhenRequired(test)
            % An empty arguments object is missing every required input.
            p.name = "toyScalarTwo";
            p.arguments = struct();
            test.verifyInputError(p, "empty params.arguments");
        end

        function missingParamsEntirely(test)
            % 2025-06-18 only: applyProtocol must synthesize params to carry
            % _meta under 2026-07-28, so a truly params-less body is not
            % expressible there.
            test.assumeEqual(test.protocol, "2025-06-18", ...
                "A 2026-07-28 request carries _meta inside params");
            test.verifyProtocolError([], "no params member");
        end

        function missingArgumentsWhenNoneRequired(test)
            % The complement: toyZeroInputs requires nothing, so omitting
            % 'arguments' is a legal call that must succeed, not a -32602.
            % This is what stops the guard above from over-rejecting.
            p.name = "toyZeroInputs";
            [response, decoded] = test.post(p);
            test.verifyEqual(response.HttpCode, 200);
            test.verifyFalse(isfield(decoded,'error'), ...
                "A zero-input tool must accept a call with no arguments");
            test.assertTrue(isfield(decoded,'result'));
            if isfield(decoded.result,'isError')
                test.verifyFalse(logical(decoded.result.isError), ...
                    "toyZeroInputs should have run cleanly");
            end
        end

        function toolThatFailsIsInBandError(test)
            % The dividing line: the tool was found and ran, so its failure
            % is content, not a protocol error. HTTP 200, result.isError
            % true, and no JSON-RPC error member at all.
            p.name = "toyScalarTwo";
            p.arguments = struct('s', "abc", 'n', -1);
            [response, decoded] = test.post(p);
            test.verifyEqual(response.HttpCode, 200, ...
                "A tool-execution failure must not change the status");
            test.verifyFalse(isfield(decoded,'error'), ...
                "A tool that ran and failed is not a protocol error");
            test.assertTrue(isfield(decoded,'result'));
            test.verifyTrue(isfield(decoded.result,'isError'));
            test.verifyTrue(logical(decoded.result.isError));
            test.verifyNotEmpty(decoded.result.content, ...
                "The tool's message must reach the model");
        end

        function toolErrorTextHasNoSourceLocation(test)
            % The model reads the tool's message, not a "file:line : "
            % location. 1.5 prefixed one; dropping it is deliberate (see
            % handler.tools.call), so a reversion must fail here.
            p.name = "toyScalarTwo";
            p.arguments = struct('s', "abc", 'n', -1);
            [~, decoded] = test.post(p);
            test.assertTrue(isfield(decoded,'result') && ...
                isfield(decoded.result,'isError') && ...
                logical(decoded.result.isError));
            msg = string(decoded.result.content(1).text);
            test.verifyEmpty(regexp(msg, "^\S+:\d+ : ", "once"), ...
                "Tool-error text must not start with a source location: " + msg);
        end

        function rejectedInputNamesItsPosition(test)
            % D36: the arguments-block message the model reads must name the
            % input it rejected. Calling the tool through feval counts the
            % function name as argument 1, so a bad first input was reported
            % at position 2 and a bad second input at position 3.
            % toyPositiveTwo's constraints aren't in its schema, so these
            % values pass validation and the tool's arguments block rejects
            % them.
            p.name = "toyPositiveTwo";

            p.arguments = struct('a', -1, 'b', 1);
            test.verifyRejectedAt(p, 1, "negative a");

            p.arguments = struct('a', 1, 'b', -1);
            test.verifyRejectedAt(p, 2, "negative b");
        end

        function rejectedInputPositionOutsideDispatcher(test)
            % The test above passes even against feval, and cannot be made
            % not to: feval's miscount depends on how its CALLER was reached.
            % Inside a function that was itself invoked through feval -- as
            % ProtocolDispatcher invokes every handler -- the inner feval
            % counts correctly; reached directly or through a handle, it is
            % one too high. So this calls the handler directly, which is the
            % context that exposes a reversion to feval, and which any change
            % to how the dispatcher invokes handlers would make the live one.
            jrpc.jsonrpc = "2.0";
            jrpc.id = 1;
            jrpc.method = "tools/call";
            jrpc.params.name = "toyPositiveTwo";

            cases = {
                struct('a', -1, 'b', 1),  1, "negative a"
                struct('a', 1, 'b', -1),  2, "negative b"
                };
            for k = 1:size(cases,1)
                jrpc.params.arguments = cases{k,1};
                result = prodserver.mcp.handler.tools.call(jrpc, test.protocol);
                test.assertTrue(isfield(result.result,'isError') && ...
                    logical(result.result.isError), cases{k,3});
                msg = string(result.result.content{1}.text);
                test.verifyTrue(contains(msg, sprintf( ...
                    "Invalid argument at position %d.", cases{k,2})), ...
                    cases{k,3} + ": " + msg);
            end
        end

        function validCallStillRuns(test)
            % Positive control for rejectedInputNamesItsPosition: the same
            % tool, called correctly, runs and returns both outputs.
            p.name = "toyScalarTwo";
            p.arguments = struct('s', "abc", 'n', 1);
            [response, decoded] = test.post(p);
            test.verifyEqual(response.HttpCode, 200);
            test.verifyFalse(isfield(decoded,'error'));
            test.assertTrue(isfield(decoded,'result'));
            if isfield(decoded.result,'isError')
                test.verifyFalse(logical(decoded.result.isError), ...
                    "toyScalarTwo should have run cleanly");
            end
            test.verifyTrue(isfield(decoded.result,'structuredContent'));
            test.verifyTrue(all(isfield(decoded.result.structuredContent, ...
                {'cs','d'})));
        end

        function stringForNumberIsRejected(test)
            % The coercion defect: "3" arrived as the char '3', which an
            % arguments block accepts for a (1,1) double as 51. The schema
            % says number, so the call is rejected before the tool runs.
            p.name = "toyScalarTwo";
            for v = ["3", "abc"]
                p.arguments = struct('s', "abc", 'n', v);
                msg = test.verifyInputError(p, "n = '" + v + "'");
                test.verifySubstring(msg, ...
                    "Argument 'n': expected number, got string");
            end
        end

        function numberForStringIsRejected(test)
            p.name = "toyScalarTwo";
            p.arguments = struct('s', 7, 'n', 1);
            msg = test.verifyInputError(p, "s = 7");
            test.verifySubstring(msg, ...
                "Argument 's': expected string, got number");
        end

        function booleanForNumberIsRejected(test)
            p.name = "toyScalarTwo";
            p.arguments = struct('s', "abc", 'n', true);
            msg = test.verifyInputError(p, "n = true");
            test.verifySubstring(msg, "expected number, got boolean");
        end

        function unknownArgumentIsRejected(test)
            % Passed through, an extra argument became a name-value pair the
            % tool didn't accept: "Too many input arguments."
            p.name = "toyScalarTwo";
            p.arguments = struct('s', "abc", 'n', 1, 'zzz', 1);
            msg = test.verifyInputError(p, "extra argument zzz");
            test.verifySubstring(msg, "has no input named 'zzz'");
        end

        function scalarSatisfiesUnsizedInput(test)
            % An input with no declared size has an array schema, but a
            % MATLAB scalar is a 1x1 array: one name is a valid call.
            p.name = "toyUnsized";
            values = {"Ada", ["Ada", "Grace"]};
            for k = 1:numel(values)
                p.arguments = struct('names', values{k});
                [response, decoded] = test.post(p);
                test.verifyEqual(response.HttpCode, 200);
                test.verifyFalse(isfield(decoded,'error'));
                test.assertTrue(isfield(decoded,'result') && ...
                    isfield(decoded.result,'structuredContent'), ...
                    "toyUnsized should have run");
                test.verifyEqual(decoded.result.structuredContent.n, ...
                    numel(values{k}));
            end
        end

        function elementOfWrongTypeIsRejected(test)
            p.name = "toyUnsized";
            p.arguments = struct('names', {{"Ada", 7}});
            msg = test.verifyInputError(p, "a number among the names");
            test.verifySubstring(msg, ...
                "at index 2: expected string, got number");
        end

    end

    methods (Access = private)

        function verifyRejectedAt(test, params, position, context)
        % A tool that rejected an input: in-band isError over HTTP 200,
        % naming the rejected input's position.
            [response, decoded] = test.post(params);
            test.verifyEqual(response.HttpCode, 200, context);
            test.verifyFalse(isfield(decoded,'error'), context);
            test.assertTrue(isfield(decoded,'result'), context);
            test.assertTrue(isfield(decoded.result,'isError') && ...
                logical(decoded.result.isError), context);
            msg = string(decoded.result.content(1).text);
            test.verifyTrue(contains(msg, ...
                sprintf("Invalid argument at position %d.", position)), ...
                context + ": " + msg);
        end

    end

end
