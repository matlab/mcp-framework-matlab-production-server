classdef tToolArgumentError < matlab.unittest.TestCase
% Test prodserver.mcp.validation.toolArgumentError: tools/call arguments
% against the tool's published inputSchema, before wire decoding.

% Copyright 2026 The MathWorks, Inc.

    methods (Static)
        function t = tool(props)
            t = struct('name', "t", 'inputSchema', struct('type', "object"));
            if nargin > 0
                t.inputSchema.properties = props;
            end
        end

        function msg = check(t, args, encoding)
            if nargin < 3
                encoding = "JSON";
            end
            msg = prodserver.mcp.validation.toolArgumentError(t, args, ...
                prodserver.mcp.WireEncoding(encoding));
        end

        function w = wrapped(dataSchema)
            w = prodserver.mcp.jsonrpc.wrapInvertible(dataSchema);
        end
    end

    methods (TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods (Test)

        function validArguments(test)
            t = test.tool(struct('n', struct('type', "number"), ...
                'v', struct('type', "array", 'items', struct('type', "number"))));
            test.verifyEqual(test.check(t, struct('n', 1, 'v', [1 2 3])), "");
            % A MATLAB scalar is a 1x1 array.
            test.verifyEqual(test.check(t, struct('n', 1, 'v', 4)), "");
            % Missing arguments are someone else's business.
            test.verifyEqual(test.check(t, struct()), "");
        end

        function unknownArgument(test)
            t = test.tool(struct('n', struct('type', "number")));
            test.verifyEqual(test.check(t, struct('m', 1)), ...
                "Tool 't' has no input named 'm'. Its inputs are: n.");
            test.verifyEqual(test.check(test.tool(), struct('m', 1)), ...
                "Tool 't' takes no inputs, but received 'm'.");
        end

        function messagesUseJSONTerms(test)
            % The client sent JSON; the message doesn't name MATLAB classes.
            t = test.tool(struct('n', struct('type', "number")));
            test.verifyEqual(test.check(t, struct('n', "x")), ...
                "Argument 'n': expected number, got string.");
        end

        function invertibleBareAndWrapped(test)
            t = test.tool(struct('n', test.wrapped(struct('type', "array", ...
                'items', struct('type', "number")))));
            ok = {1, "NaN", "-Inf", ...
                struct('type', "double", 'size', [1 2], 'data', {{1, "Inf"}})};
            for k = 1:numel(ok)
                test.verifyEqual(test.check(t, struct('n', {ok{k}}), "Invertible"), ...
                    "", jsonencode(ok{k}));
            end
            % A string is a number only if it is NaN, Inf or -Inf. The
            % failure is explained against the bare form.
            test.verifyEqual(test.check(t, struct('n', "3"), "Invertible"), ...
                "Argument 'n': expected number, got string.");
        end

        function wrapperOnlyUnderInvertible(test)
            % Under JSON the published schema is all there is.
            t = test.tool(struct('n', test.wrapped(struct('type', "number"))));
            test.verifyNotEqual(test.check(t, struct('n', 1), "JSON"), "");
        end

        function wrapperDataWithoutOneType(test)
            % The example path publishes these; checking must not fail.
            noType = test.wrapped(struct('description', "Unobserved"));
            mixed = test.wrapped(struct('anyOf', ...
                {{struct('type', "number"), struct('type', "string")}}));
            items = test.wrapped(struct('type', "array", 'items', ...
                struct('anyOf', {{struct('type', "number"), struct('type', "string")}})));
            t = test.tool(struct('a', noType, 'b', mixed, 'c', items));
            w = @(d) struct('type', "double", 'size', [1 1], 'data', d);
            test.verifyEqual(test.check(t, struct('a', w(1), 'b', w(2), ...
                'c', w(3)), "Invertible"), "");
            % Bare: anything for unconstrained data, an alternative for
            % anyOf data.
            test.verifyEqual(test.check(t, struct('a', true, 'b', "x"), ...
                "Invertible"), "");
            test.verifyEqual(test.check(t, struct('b', "NaN"), "Invertible"), "");
            test.verifyNotEqual(test.check(t, struct('b', true), "Invertible"), "");
        end

        function structArrayIsNotAnObject(test)
            t = test.tool(struct('s', struct('type', "object")));
            test.verifySubstring(test.check(t, struct('s', {struct('a', {1, 2})})), ...
                "expected object, got an array of 2");
        end

        function dateTimeText(test)
            % "format": "date-time" is checked, under either encoding.
            import prodserver.mcp.jsonrpc.WireShape
            inv = prodserver.mcp.jsonrpc.wireTypeSchema("datetime", WireShape.Scalar);
            t = test.tool(struct('d', inv));
            test.verifyEqual(test.check(t, struct('d', "2026-01-02T03:04:05Z"), ...
                "Invertible"), "");
            test.verifyEqual(test.check(t, struct('d', "NaT"), "Invertible"), "");
            test.verifyNotEqual(test.check(t, struct('d', "garbage"), "Invertible"), "");
            % A zoned scalar's wrapper is a form too.
            w = struct('type', "datetime", 'size', [1 1], ...
                'tz', "America/New_York", 'data', {{"2026-01-02T03:04:05.000-05:00"}});
            test.verifyEqual(test.check(t, struct('d', w), "Invertible"), "");
            % Under JSON, the message says what's wrong, not just "one of
            % [string, null]".
            t = test.tool(struct('d', prodserver.mcp.jsonrpc.jsonTimeSchema( ...
                "datetime", WireShape.Scalar)));
            test.verifyEqual(test.check(t, struct('d', "01/02/2026")), ...
                "Argument 'd': expected an ISO 8601 date-time, such as " + ...
                "2026-01-02T03:04:05Z, got '01/02/2026'.");
        end

        function examplePathSchemas(test)
            % An example that skips inputs leaves them without a type; a
            % call that passes them must still be checked, not fail.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));
            for enc = ["JSON" "Invertible"]
                defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                    @() schemaFlexNoBlock(1, 2, 3), encoding=enc);
                args = struct('a', 1, 'b', 2, 'c', 3, 'd', 4, 'e', "five");
                test.verifyEqual(test.check(defs.tools, args, enc), "", enc);
            end
        end

    end
end
