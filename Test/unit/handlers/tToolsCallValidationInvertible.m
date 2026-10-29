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
            test.fcnNames = "toyPositiveTwo";
            test.toolNames = test.fcnNames;
            defineTools(test,test.fcnNames,test.toolNames, ...
                encoding=prodserver.mcp.WireEncoding.Invertible);
        end
    end

    methods
        function decoded = call(test, args)
            import prodserver.mcp.MCPConstants
            req = test.request;
            req.Headers = [req.Headers; {MCPConstants.ContentType, ...
                'application/json'}];
            body = jsonencode(struct('jsonrpc', "2.0", 'id', 1, ...
                'method', "tools/call", 'params', struct( ...
                'name', "toyPositiveTwo", 'arguments', args)));
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

        function verifyRejected(test, args, context)
            decoded = test.call(args);
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
