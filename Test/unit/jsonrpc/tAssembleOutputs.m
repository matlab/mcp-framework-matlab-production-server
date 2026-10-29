classdef tAssembleOutputs < matlab.unittest.TestCase
% Test prodserver.mcp.internal.assembleOutputs: the positional output
% contract of prodserver.mcp.call (v1.4.1's, adopted in conformance Phase XA,
% XD23).

% Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        Endpoint = "http://localhost:9910/srv/mcp";
        Encoding = prodserver.mcp.WireEncoding.JSON;
    end

    methods

        function out = assemble(test, def, sig, data, nout)
            out = prodserver.mcp.internal.assembleOutputs("t", ...
                test.Endpoint, def, sig, data, nout, test.Encoding);
        end

    end

    methods (Static)

        function def = definition(requiredJson)
            def = jsondecode(['{"name":"t","outputSchema":{"type":"object"' ...
                requiredJson '}}']);
        end

        function sig = signature(names)
            sig.t.function = "t";
            if nargin > 0
                sig.t.output.name = cellstr(names);
            end
        end

        function data = result(structured)
            data.jsonrpc = "2.0";
            data.id = 1;
            data.result.structuredContent = structured;
            data.result.content = {struct('type',"text",'text',"{}")};
        end

    end

    methods (Test)

        function tOrderedBySchemaThenSignature(test)
            % The wire's field order is c, b, a. Schema says a; signature
            % adds b, c. Positional order is a, b, c.
            data = test.result(struct('c', 3, 'b', 2, 'a', 1));
            out = test.assemble(test.definition(',"required":["a"]'), ...
                test.signature(["b","c"]), data, 3);
            test.verifyEqual(out, {1, 2, 3});
        end

        function tStatementCallStillGetsAns(test)
            data = test.result(struct('a', 1, 'b', 2));
            out = test.assemble(test.definition(',"required":["a","b"]'), ...
                test.signature(["a","b"]), data, 0);
            test.verifyEqual(out, {1});
        end

        function tSurplusOutputsAreDropped(test)
            data = test.result(struct('a', 1, 'b', 2, 'extra', 9));
            out = test.assemble(test.definition(',"required":["a","b"]'), ...
                test.signature(["a","b"]), data, 1);
            test.verifyEqual(out, {1});
        end

        function tTooFewOutputs(test)
            data = test.result(struct('a', 1));
            try
                test.assemble(test.definition(',"required":["a"]'), ...
                    test.signature("a"), data, 2);
                test.verifyFail("Expected TooFewOutputs");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:TooFewOutputs');
                test.verifyTrue(contains(err.message, test.Endpoint), err.message);
            end
        end

        function tMissingOutputsNamesToolAndEndpoint(test)
            % The signature declares b; the server did not send it.
            data = test.result(struct('a', 1));
            try
                test.assemble(test.definition(',"required":[]'), ...
                    test.signature(["a","b"]), data, 2);
                test.verifyFail("Expected MissingOutputs");
            catch err
                test.verifyEqual(err.identifier, 'prodserver:mcp:MissingOutputs');
                test.verifyTrue(contains(err.message, "t at " + test.Endpoint), ...
                    err.message);
                test.verifyTrue(endsWith(strtrim(err.message), "b."), err.message);
            end
        end

        function tEmptyRequiredIsNotRequired(test)
            % Generated tools always send "required":[] for outputs. That
            % must not demand structuredContent.
            data.jsonrpc = "2.0";
            data.id = 1;
            data.result.content = {struct('type',"text",'text',"hi")};
            out = test.assemble(test.definition(',"required":[]'), ...
                test.signature(), data, 1);
            test.verifyEqual(out{1}, data.result.content);
        end

        function tRequiredWithoutStructuredContent(test)
            data.jsonrpc = "2.0";
            data.id = 1;
            data.result.content = {struct('type',"text",'text',"hi")};
            test.verifyError(@() test.assemble( ...
                test.definition(',"required":["a"]'), test.signature("a"), ...
                data, 1), "prodserver:mcp:NoStructuredContent");
        end

        function tNoDeclaredOutputs(test)
            % Nothing names the outputs: fine for a statement call, an
            % error if the caller asked for one.
            data = test.result(struct());
            out = test.assemble(test.definition(''), test.signature(), data, 0);
            test.verifyEqual(out, {});
            test.verifyError(@() test.assemble(test.definition(''), ...
                test.signature(), data, 1), "prodserver:mcp:TooFewOutputs");
        end

        function tZeroInputToolOutputs(test)
            % The shape toyZeroInputs gets from a deployed archive: no
            % 'input' in the signature, five named outputs.
            names = ["n","extent","hero","area","cover"];
            sig = test.signature(names);
            sig.t.encoding = "JSON";
            vals = struct('n', 3, 'extent', 12, 'hero', struct('x',3), ...
                'area', 6, 'cover', 6);
            out = test.assemble(test.definition(',"required":[]'), sig, ...
                test.result(vals), 5);
            test.verifyEqual(out, {3, 12, struct('x',3), 6, 6});
        end

        function tJSONTimesDecoded(test)
            % The output schema says which plain JSON values are datetimes
            % and durations.
            import prodserver.mcp.jsonrpc.WireShape
            def = test.definition(',"required":["when","gap","label"]');
            def.outputSchema.properties = struct( ...
                'when', prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", WireShape.Scalar), ...
                'gap', prodserver.mcp.jsonrpc.jsonTimeSchema("duration", WireShape.Scalar), ...
                'label', struct('type', "string"));
            data = test.result(struct('when', '2026-01-02T03:04:05.000Z', ...
                'gap', 90, 'label', '2026-01-02'));
            out = test.assemble(def, test.signature(), data, 3);
            test.verifyEqual(out, {datetime(2026,1,2,3,4,5, TimeZone="UTC"), ...
                seconds(90), '2026-01-02'});

            data = test.result(struct('when', 'later', 'gap', 90, 'label', ''));
            test.verifyError(@() test.assemble(def, test.signature(), data, 3), ...
                "prodserver:mcp:UndecodableOutput");
        end

        function tAllNullDatetimeOutput(test)
            import prodserver.mcp.jsonrpc.WireShape
            def = test.definition(',"required":["when"]');
            def.outputSchema.properties = struct('when', ...
                prodserver.mcp.jsonrpc.jsonTimeSchema("datetime", WireShape.Array));
            data = jsondecode(jsonencode(test.result(struct('when', ...
                prodserver.mcp.jsonrpc.plainJSONValue([NaT NaT])))));
            out = test.assemble(def, test.signature(), data, 1);
            test.verifyTrue(all(isnat(out{1})));
            test.verifyNumElements(out{1}, 2);
        end

        function tInvertibleTimesNotReinterpreted(test)
            % Wire decoding has its own forms; the JSON conversion doesn't
            % apply.
            import prodserver.mcp.jsonrpc.WireShape
            def = test.definition(',"required":["gap"]');
            def.outputSchema.properties = struct('gap', ...
                prodserver.mcp.jsonrpc.jsonTimeSchema("duration", WireShape.Scalar));
            data = test.result(struct('gap', 90));
            out = prodserver.mcp.internal.assembleOutputs("t", test.Endpoint, ...
                def, test.signature(), data, 1, prodserver.mcp.WireEncoding.Invertible);
            test.verifyEqual(out, {90});
        end

    end

end
