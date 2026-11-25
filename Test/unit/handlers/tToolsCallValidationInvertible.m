classdef tToolsCallValidationInvertible < prodserver.mcp.test.base.MCPHandlerBase
% tools/call argument validation under Invertible encoding. An argument
% may be sent wrapped ({"type","size","data"}) or, for a scalar, bare, as
% wire_encoding_rules.txt allows. A bare string is a number only if it is
% "NaN", "Inf" or "-Inf": anything else for a number is rejected before the
% tool runs, because decoding would make it a char.

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function prepareTools(test)
            import matlab.unittest.fixtures.PathFixture
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(PathFixture(...
                fullfile(prodserver.mcp.internal.packageFolder(), ...
                         "server","tools")));
            % toyEnum's input has a numeric enum; toyTotal's is a oneOf of
            % a number and an array.
            test.fcnNames = ["toyPositiveTwo" "toyEnum" "toyTotal"];
            test.toolNames = test.fcnNames;
            defineTools(test,test.fcnNames,test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.Invertible);
        end
    end

    methods
        function decoded = call(test, args, tool)
            arguments
                test
                args
                tool (1,1) string = "toyPositiveTwo"
            end
            import prodserver.mcp.MCPConstants
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];
            body = jsonencode(struct('jsonrpc', "2.0", 'id', 1, ...
                'method', "tools/call", 'params', struct( ...
                'name', tool, 'arguments', args)));
            [req, body] = test.applyProtocol(req, body);
            req.Method = "POST";
            req.Path = "/toyPositiveTwo/mcp";
            req.Headers = [req.Headers; {MCPConstants.ContentLength, numel(body)}];
            req.Body = unicode2native(body, "UTF-8");
            decoded = prodserver.mcp.internal.decodeBody(test.handle(req));
        end

        function verifyRan(test, args, expected, context)
            decoded = test.call(args);
            test.verifyFalse(isfield(decoded, 'error'), context);
            test.assertTrue(isfield(decoded, 'result') && ...
                isfield(decoded.result, 'structuredContent'), context);
            s = decoded.result.structuredContent.s;
            % Decode as a client would: a wrapper, or a bare special float.
            s = prodserver.mcp.jsonrpc.mcpWireDecodeValue(s);
            test.verifyEqual(double(s), expected, context);
        end

        function verifyRejected(test, args, context, tool)
            arguments
                test
                args
                context
                tool (1,1) string = "toyPositiveTwo"
            end
            decoded = test.call(args, tool);
            if prodserver.mcp.protocol.inputErrorsAreToolErrors(test.protocol)
                test.assertTrue(isfield(decoded, 'result') && ...
                    isfield(decoded.result, 'isError') && ...
                    logical(decoded.result.isError), context);
                test.verifyTrue(startsWith(string( ...
                    decoded.result.content(1).text), ...
                    "Input validation error: "), context);
            else
                test.assertTrue(isfield(decoded, 'error'), context);
                test.verifyEqual(decoded.error.code, -32602, context);
            end
        end
    end

    methods (Test)
        function enumMemberAcceptedBareOrWrapped(test)
            w = @(x) struct('type', "double", 'size', [1 1], 'data', x);
            for args = {struct('level', 2), struct('level', w(2))}
                decoded = test.call(args{1}, "toyEnum");
                test.verifyFalse(isfield(decoded, 'error'));
                test.assertTrue(isfield(decoded, 'result') && ...
                    isfield(decoded.result, 'structuredContent'));
                test.verifyEqual(double(prodserver.mcp.jsonrpc.mcpWireDecodeValue( ...
                    decoded.result.structuredContent.y)), 2);
            end
        end

        function oneOfNumberOrArrayRuns(test)
            % The oneOf is on the wrapper's data: a one-element array
            % arrives as a number, which matched both branches.
            w = @(sz, x) struct('type', "double", 'size', sz, 'data', x);
            cases = {struct('x', 7), 7
                     struct('x', w([1 1], 7)), 7
                     struct('x', w([1 2], [1 2])), 3};
            for k = 1:size(cases, 1)
                decoded = test.call(cases{k,1}, "toyTotal");
                test.verifyFalse(isfield(decoded, 'error'));
                test.assertTrue(isfield(decoded, 'result') && ...
                    isfield(decoded.result, 'structuredContent'), ...
                    "toyTotal should have run: " + jsonencode(cases{k,1}));
                test.verifyEqual(double(prodserver.mcp.jsonrpc.mcpWireDecodeValue( ...
                    decoded.result.structuredContent.t)), cases{k,2});
            end
        end

        function enumNonMemberRejectedBareOrWrapped(test)
            % The bare form was the element's type alone, so a bare 4 ran.
            w = @(x) struct('type', "double", 'size', [1 1], 'data', x);
            test.verifyRejected(struct('level', 4), "bare 4", "toyEnum");
            test.verifyRejected(struct('level', "NaN"), "bare NaN", "toyEnum");
            test.verifyRejected(struct('level', w(4)), "wrapped 4", "toyEnum");
        end

        function bareScalarsAccepted(test)
            test.verifyRan(struct('a', 1, 'b', 2), 3, "bare numbers");
        end

        function wrappedScalarsAccepted(test)
            w = @(x) struct('type', "double", 'size', [1 1], 'data', x);
            test.verifyRan(struct('a', w(1), 'b', w(2)), 3, "wrapped numbers");
        end

        function stringForNumberRejected(test)
            test.verifyRejected(struct('a', "3", 'b', 2), "a = '3'");
        end

        function specialFloatStringPassesValidation(test)
            % "Inf" is a number in the encoding, and positive, so the call
            % runs.
            test.verifyRan(struct('a', "Inf", 'b', 2), Inf, "a = 'Inf'");
        end

        function argumentsArrayRejected(test)
            % A JSON array of objects decodes to a struct array.
            test.verifyRejected(struct('a', {1, 2}, 'b', {2, 3}), ...
                "arguments array");
        end

        function emptyTextArgumentsRejected(test)
            % Only null stands for no arguments; "" is not an object.
            decoded = test.call("");
            if prodserver.mcp.protocol.inputErrorsAreToolErrors(test.protocol)
                text = string(decoded.result.content(1).text);
            else
                text = string(decoded.error.message);
            end
            test.verifySubstring(text, "must be a JSON object");
        end

        function undecodableArgumentRejected(test)
            % A wrapper whose data doesn't fill its size can't be decoded.
            w = struct('type', "double", 'size', [1 1], 'data', [1 2]);
            test.verifyRejected(struct('a', w, 'b', 2), "short wrapper");
        end
    end
end
