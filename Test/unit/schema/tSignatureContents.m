classdef tSignatureContents < matlab.unittest.TestCase
% What a definition's signatures report, as /signature returns them: each
% parameter's MATLAB class, declared size, validators and default.
%
% A definition made from example calls (SchemaObserver) used to report
% every class it didn't see declared as double, and no sizes or defaults
% at all, while one made from the arguments block alone (mcpDefinition)
% reported them. The two now read the arguments block the same way, and
% must agree wherever both apply.

% Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        % An example's value, and the class its signature must report.
        value = struct("int8", int8(5), "logical", true, ...
            "datetime", datetime(2026,1,1), "struct", struct('a', 1), ...
            "char", 'abc', "string", ["a" "b"])
    end

    methods (TestClassSetup)
        function requireTools(test)
            test.applyFixture(prodserver.mcp.test.mixin.RequireToyTools());
            test.applyFixture(prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods (Test)

        function observedClassIsTheType(test, value)
            d = prodserver.mcp.schema("schemaWireAny", ...
                @() schemaWireAny(value), encoding="Invertible");
            test.verifyEqual(d.signatures.schemaWireAny.input.type, ...
                string(class(value)));
        end

        function differingClassesAreJoined(test)
            d = prodserver.mcp.schema("schemaWireAny", ...
                {@() schemaWireAny(uint16(3)), @() schemaWireAny(2.5)}, ...
                encoding="Invertible");
            test.verifyEqual(d.signatures.schemaWireAny.input.type, ...
                "uint16|double", "In the order the examples passed them.");
        end

        function noClassIsUnknown(test)
            % No declared class, and no example: the type is unknown, not
            % a guess. The declared size is still reported.
            d = prodserver.mcp.internal.mcpDefinition("toyUntypedSize", ...
                "toyUntypedSize");
            sig = d.signatures.toyUntypedSize.input;
            test.verifyEqual(sig.type, "");
            test.verifyEqual(string(sig.validation{1}.size), "(1,:)");
            test.verifyEqual(string(sig.validation{1}.type), "");

            % An example says what it is.
            d = prodserver.mcp.schema("toyUntypedSize", ...
                @() toyUntypedSize([1 2]));
            sig = d.signatures.toyUntypedSize.input;
            test.verifyEqual(sig.type, "double");
            test.verifyEqual(string(sig.validation{1}.size), "(1,:)");
        end

        function declaredAndObservedAgree(test)
            % Sizes, classes and defaults (numeric and string) come from
            % the arguments block either way.
            declared = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarOptions", "toyScalarOptions");
            observed = prodserver.mcp.schema("toyScalarOptions", ...
                @() toyScalarOptions(2020));
            d = declared.signatures.toyScalarOptions;
            o = observed.signatures.toyScalarOptions;
            test.verifyEqual(jsonencode(o.input), jsonencode(d.input));
            test.verifyEqual(jsonencode(o.output), jsonencode(d.output));
            test.verifyEqual(string(o.input.default.mpg), "3.49");
            test.verifyEqual(string(o.input.default.make), """Lockheed""");
            test.verifyEqual(string(o.input.validation{1}.size), "(1,1)");
        end

    end

end
