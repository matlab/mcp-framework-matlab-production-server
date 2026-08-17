classdef tSchemaArgCounts < matlab.unittest.TestCase
%tSchemaArgCounts Test observed argument count inference for no-block functions.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function allArgsRequired(test)
            % Exercise with all 5 args every time → all required
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                @() schemaFlexNoBlock(1,2,3,4,5), encoding="JSON");
            test.verifyEqual(numel(defs.tools.inputSchema.required), 5);
            test.verifyTrue(all(ismember(["a","b","c","d","e"], ...
                defs.tools.inputSchema.required)));
        end

        function threeRequiredTwoOptional(test)
            % Minimum call uses 3 args → a,b,c required; d,e optional
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1,2,3), ...
                 @() schemaFlexNoBlock(1,2,3,4,5)}, encoding="JSON");
            test.verifyEqual(numel(defs.tools.inputSchema.required), 3);
            test.verifyTrue(all(ismember(["a","b","c"], ...
                defs.tools.inputSchema.required)));
            test.verifyFalse(ismember("d", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("e", defs.tools.inputSchema.required));
        end

        function oneRequiredFourOptional(test)
            % Minimum call uses 1 arg → only a required
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1), ...
                 @() schemaFlexNoBlock(1,2,3,4,5)}, encoding="JSON");
            test.verifyEqual(numel(defs.tools.inputSchema.required), 1);
            test.verifyTrue(ismember("a", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("b", defs.tools.inputSchema.required));
        end

        function noneRequired(test)
            % Minimum call uses 0 args → none required
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(), ...
                 @() schemaFlexNoBlock(1,2,3)}, encoding="JSON");
            test.verifyTrue(isempty(defs.tools.inputSchema.required));
        end

        function minMaxProperties(test)
            % With 2 required and 3 optional, min=2 max=5
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1,2), ...
                 @() schemaFlexNoBlock(1,2,3,4,5)}, encoding="JSON");
            test.verifyEqual(defs.tools.inputSchema.minProperties, 2);
            test.verifyEqual(defs.tools.inputSchema.maxProperties, 5);
        end

        function parameterKindCorrect(test)
            % Verify signature kinds match observation
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1,2), ...
                 @() schemaFlexNoBlock(1,2,3,4,5)}, encoding="JSON");
            import prodserver.mcp.internal.ParameterKind
            sig = defs.signatures.schemaFlexNoBlock.input;
            kinds = ParameterKind(sig.kind);
            test.verifyEqual(kinds(1), ParameterKind.Required);
            test.verifyEqual(kinds(2), ParameterKind.Required);
            test.verifyEqual(kinds(3), ParameterKind.Optional);
            test.verifyEqual(kinds(4), ParameterKind.Optional);
            test.verifyEqual(kinds(5), ParameterKind.Optional);
        end

        function argBlockFunctionUnchanged(test)
            % Functions with argument blocks still use metadata
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() schemaCompute(1,2,3), encoding="JSON");
            test.verifyTrue(all(ismember(["x","y","z"], ...
                defs.tools.inputSchema.required)));
        end

        function threeArgNoBlockAllRequired(test)
            % schemaComputeNoBlock has 3 declared params, exercise with 3
            defs = prodserver.mcp.schema("schemaComputeNoBlock", ...
                @() schemaComputeNoBlock(1,2,3), encoding="JSON");
            test.verifyEqual(numel(defs.tools.inputSchema.required), 3);
            test.verifyTrue(all(ismember(["x","y","z"], ...
                defs.tools.inputSchema.required)));
        end

        function vectorNoBlockOptionalScale(test)
            % schemaVectorNoBlock: exercise with 1 and 2 args
            defs = prodserver.mcp.schema("schemaVectorNoBlock", ...
                {@() schemaVectorNoBlock([1,2,3]), ...
                 @() schemaVectorNoBlock([1,2,3], 2.0)}, encoding="JSON");
            test.verifyEqual(numel(defs.tools.inputSchema.required), 1);
            test.verifyTrue(ismember("values", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("scale", defs.tools.inputSchema.required));
        end

        function structuredTypeAllRequired(test)
            defs = prodserver.mcp.schema("schemaTableNoBlock", ...
                @() schemaTableNoBlock(["A","B"], [1,2], "X"), ...
                encoding="JSON");
            test.verifyEqual(numel(defs.tools.inputSchema.required), 3);
            test.verifyTrue(all(ismember(["names","ages","city"], ...
                defs.tools.inputSchema.required)));
        end

    end
end
