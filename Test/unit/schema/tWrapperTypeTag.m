classdef tWrapperTypeTag < matlab.unittest.TestCase
% The invertible wrapper's "type" tag: what an input may be tagged with
% (what MATLAB converts to the parameter's class) and what an output is
% (the class the server sends).

% Copyright 2026 The MathWorks, Inc.

    methods (TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods (Test)

        function inputsTakeWhatConverts(test)
            import prodserver.mcp.internal.Constants
            f = @prodserver.mcp.jsonrpc.wrapperTypeSchema;
            numeric = [Constants.NumericClasses "logical"];
            for c = ["double" "int16" "logical"]
                test.verifyEqual(string(f(c, "input").enum(:))', numeric, c);
            end
            % A string takes char, but a char doesn't take a string: a
            % string array may be ragged.
            test.verifyEqual(string(f("string", "input").enum(:))', ["char" "string"]);
            test.verifyEqual(f("char", "input"), struct('enum', {{"char"}}));
            test.verifyEqual(f("struct", "input"), struct('enum', {{"struct"}}));
            test.verifyEqual(f("cell", "input"), struct('enum', {{"cell"}}));
        end

        function outputsAreExact(test)
            f = @prodserver.mcp.jsonrpc.wrapperTypeSchema;
            test.verifyEqual(f("double", "output"), struct('enum', {{"double"}}));
            test.verifyEqual(string(f(["uint16" "double"], "output").enum(:))', ...
                ["uint16" "double"]);
        end

        function unknownIsAnyDiscriminator(test)
            % Every class the decoder knows: not "foo".
            f = @prodserver.mcp.jsonrpc.wrapperTypeSchema;
            all = prodserver.mcp.jsonrpc.WireSupport.classNames();
            test.verifyEqual(string(f(string.empty, "input").enum(:))', all);
            test.verifyEqual(string(f("datetime", "input").enum(:))', all, ...
                "Not a class the generic wrapper carries");
            % And the wrapper is still the generic one, with its bare forms.
            w = prodserver.mcp.jsonrpc.wrapInvertible(struct(), f(string.empty, "input"));
            test.verifyTrue(prodserver.mcp.jsonrpc.isGenericWrapper(w));
        end

        function validatorsAdmit(test)
            import prodserver.mcp.internal.Constants
            v = @prodserver.mcp.jsonrpc.validatorClasses;
            test.verifyEqual(v("{mustBeNumeric}"), Constants.NumericClasses);
            test.verifyEqual(v("(1,:) {mustBeInteger}"), [Constants.NumericClasses "logical"]);
            test.verifyEqual(v("{mustBeTextScalar}"), ["char" "string"]);
            % Several: the classes all of them admit.
            test.verifyEqual(v("{mustBeFloat, mustBePositive}"), Constants.FloatClasses);
            test.verifyEqual(v("{mustBeText, mustBeNonempty}"), ["char" "string" "cell"]);
            % None it knows, or none at all.
            test.verifyEmpty(v("{mustBeNonempty, mustBeInRange(x, 0, 1)}"));
            test.verifyEmpty(v("(1,:) double"));
            % A validator's own braces, brackets, commas and quoted text
            % neither end the list nor name a validator.
            test.verifyEqual(v("{mustBeMember(x,{'a','b'}), mustBeNumeric}"), ...
                Constants.NumericClasses);
            test.verifyEqual(v("{mustBeMember(x,[""mustBeText"" ""}""]), mustBeFloat}"), ...
                Constants.FloatClasses);
            test.verifyEqual(v("{mustBeInRange(x', 0, 1), mustBeTextScalar}"), ...
                ["char" "string"]);
            % Only the first {...}.
            test.verifyEqual(v("(1,:) {mustBeFloat} = {mustBeText}"), ...
                Constants.FloatClasses);
            % Used as they are when there's no class.
            tag = prodserver.mcp.jsonrpc.wrapperTypeSchema(string.empty, "input", ...
                Constants.FloatClasses);
            test.verifyEqual(string(tag.enum(:))', Constants.FloatClasses);
        end

        function validatorsOnBothPaths(test)
            import prodserver.mcp.internal.Constants
            d = prodserver.mcp.internal.mcpDefinition("schemaValidated", ...
                "schemaValidated", encoding="Invertible");
            e = prodserver.mcp.schema("schemaValidated", ...
                @() schemaValidated([1 2], "x", 1.5, {1}), encoding="Invertible");
            tags = @(p) string(prodserver.mcp.test.wrapperOf(p).properties.type.enum(:))';
            in = d.tools.inputSchema.properties;
            test.verifyEqual(tags(in.a), Constants.NumericClasses, "a");
            test.verifyEqual(tags(in.b), ["char" "string" "cell"], "b");
            test.verifyEqual(tags(in.c), Constants.FloatClasses, "c");
            test.verifyEqual(tags(in.d), prodserver.mcp.jsonrpc.WireSupport.classNames(), "d");
            % The example path takes the validators too, over what it saw.
            in = e.tools.inputSchema.properties;
            test.verifyEqual(tags(in.a), Constants.NumericClasses, "example a");
            test.verifyEqual(tags(in.c), Constants.FloatClasses, "example c");
        end

        function bothPathsTagTheWrapper(test)
            % Declared: schemaUnobserved declares x (1,1) double and outputs
            % a (1,1) double, b (1,1) string.
            d = prodserver.mcp.internal.mcpDefinition("schemaUnobserved", ...
                "schemaUnobserved", encoding="Invertible");
            e = prodserver.mcp.schema("schemaUnobserved", ...
                @() schemaUnobserved(2), encoding="Invertible");
            for defs = {d, e}
                p = defs{1}.tools;
                test.verifyTrue(ismember("double", ...
                    string(prodserver.mcp.test.wrapperOf(p.inputSchema.properties.x).properties.type.enum)));
                test.verifyEqual(prodserver.mcp.test.wrapperOf(p.outputSchema.properties.a).properties.type, ...
                    struct('enum', {{"double"}}));
                test.verifyEqual(prodserver.mcp.test.wrapperOf(p.outputSchema.properties.b).properties.type, ...
                    struct('enum', {{"string"}}));
                % The generic wrapper, published with its bare forms.
                test.verifyTrue(prodserver.mcp.jsonrpc.bareOrWrapped( ...
                    p.inputSchema.properties.x));
            end
        end

        function observedClassesTagTheWrapper(test)
            % No arguments block: the examples' classes decide.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));
            defs = prodserver.mcp.schema("schemaComputeNoBlock", ...
                {@() schemaComputeNoBlock(uint16([1 2]), 2, 3), ...
                 @() schemaComputeNoBlock([1 2], 2, 3)}, encoding="Invertible");
            x = prodserver.mcp.test.wrapperOf(defs.tools.inputSchema.properties.x);
            test.verifyTrue(all(ismember(["uint16" "double"], ...
                string(x.properties.type.enum))));
        end

        function wrongTagRejected(test)
            % A tag the parameter's class doesn't convert from fails
            % validation, with a message naming what was expected.
            tag = prodserver.mcp.jsonrpc.wrapperTypeSchema("double", "input");
            t = struct('name', "t", 'inputSchema', struct('type', "object", ...
                'properties', struct('x', prodserver.mcp.jsonrpc.wrapInvertible( ...
                struct('type', "array", 'items', struct('type', "number")), tag))));
            w = @(c) struct('type', c, 'size', [1 2], 'data', [1 2]);
            f = @(v) prodserver.mcp.validation.toolArgumentError(t, ...
                struct('x', v), prodserver.mcp.WireEncoding.Invertible);
            test.verifyEqual(f(w("int32")), "", "A numeric class converts");
            msg = f(w("banana"));
            test.verifySubstring(msg, """banana""");
            test.verifySubstring(msg, """double""");
        end

    end
end
