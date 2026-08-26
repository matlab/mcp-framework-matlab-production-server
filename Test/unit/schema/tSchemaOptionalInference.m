classdef tSchemaOptionalInference < matlab.unittest.TestCase
%tSchemaOptionalInference Verify optional argument inference from multiple examples.
%
%   When example= contains calls with different numbers of arguments, the
%   framework infers which trailing arguments are optional. The minimum
%   observed argument count defines the required parameters; arguments
%   present only in longer calls are marked optional.
%
%   This test covers both functions with and without argument blocks.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        % --- Functions WITHOUT argument blocks ---

        function noBlockTwoOfThreeRequired(test)
            % schemaFlexNoBlock(a,b,c,d,e): call with 2 and 5 args.
            % a, b required; c, d, e optional.
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1, 2), ...
                 @() schemaFlexNoBlock(1, 2, 3, 4, 5)}, ...
                encoding="JSON");

            test.verifyEqual(numel(defs.tools.inputSchema.required), 2);
            test.verifyTrue(all(ismember(["a","b"], ...
                defs.tools.inputSchema.required)));
            test.verifyFalse(ismember("c", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("d", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("e", defs.tools.inputSchema.required));
        end

        function noBlockAllRequired(test)
            % Single call with all args → all required.
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                @() schemaFlexNoBlock(1, 2, 3, 4, 5), ...
                encoding="JSON");

            test.verifyEqual(numel(defs.tools.inputSchema.required), 5);
        end

        function noBlockVectorOptionalScale(test)
            % schemaVectorNoBlock(values, scale): call with 1 and 2 args.
            % values required; scale optional.
            defs = prodserver.mcp.schema("schemaVectorNoBlock", ...
                {@() schemaVectorNoBlock([1,2,3]), ...
                 @() schemaVectorNoBlock([1,2,3], 2.0)}, ...
                encoding="JSON");

            test.verifyEqual(numel(defs.tools.inputSchema.required), 1);
            test.verifyTrue(ismember("values", ...
                defs.tools.inputSchema.required));
            test.verifyFalse(ismember("scale", ...
                defs.tools.inputSchema.required));
        end

        % --- Functions WITH argument blocks ---

        function blockDefaultMarksOptional(test)
            % schemaOptionalWithBlock has overlap with default=0.
            % Even with a single call using all 3 args, overlap should
            % be optional because the argument block declares a default.
            defs = prodserver.mcp.schema("schemaOptionalWithBlock", ...
                @() callWithOutputs(@schemaOptionalWithBlock, 1, ...
                    {(1:10)', 3, 1}), ...
                encoding="JSON");

            test.verifyTrue(ismember("signal", ...
                defs.tools.inputSchema.required));
            test.verifyTrue(ismember("windowSize", ...
                defs.tools.inputSchema.required));
            test.verifyFalse(ismember("overlap", ...
                defs.tools.inputSchema.required), ...
                "Argument with default value must be optional.");
        end

        function blockNoDefaultAllRequired(test)
            % schemaColumnVector has no defaults — all positional required.
            defs = prodserver.mcp.schema("schemaColumnVector", ...
                @() callWithOutputs(@schemaColumnVector, 1, ...
                    {[10; 20; 30], 5.0}), ...
                encoding="JSON");

            test.verifyTrue(ismember("measurements", ...
                defs.tools.inputSchema.required));
            test.verifyTrue(ismember("threshold", ...
                defs.tools.inputSchema.required));
        end

        function blockNVPAlwaysOptional(test)
            % schemaCompute has NVP opts (scale, label). These must be
            % optional regardless of whether they appear in examples.
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() callWithOutputs(@schemaCompute, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding="JSON");

            test.verifyTrue(ismember("x", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("y", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("z", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("scale", ...
                defs.tools.inputSchema.required));
            test.verifyFalse(ismember("label", ...
                defs.tools.inputSchema.required));
        end

        % --- Interaction: block + observation ---

        function blockOptionalConfirmedByObservation(test)
            % Call schemaOptionalWithBlock with 2 and 3 args.
            % Both block metadata and observation agree: overlap is optional.
            defs = prodserver.mcp.schema("schemaOptionalWithBlock", ...
                {@() callWithOutputs(@schemaOptionalWithBlock, 1, ...
                    {(1:10)', 3}), ...
                 @() callWithOutputs(@schemaOptionalWithBlock, 1, ...
                    {(1:20)', 5, 2})}, ...
                encoding="JSON");

            test.verifyTrue(ismember("signal", ...
                defs.tools.inputSchema.required));
            test.verifyTrue(ismember("windowSize", ...
                defs.tools.inputSchema.required));
            test.verifyFalse(ismember("overlap", ...
                defs.tools.inputSchema.required));
        end

        function minMaxPropertiesNoBlock(test)
            % Verify minProperties and maxProperties reflect optionality.
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1, 2, 3), ...
                 @() schemaFlexNoBlock(1, 2, 3, 4, 5)}, ...
                encoding="JSON");

            test.verifyEqual(defs.tools.inputSchema.minProperties, 3);
            test.verifyEqual(defs.tools.inputSchema.maxProperties, 5);
        end

        function parameterKindReflectsOptional(test)
            % Verify ParameterKind is set correctly for observed optionals.
            defs = prodserver.mcp.schema("schemaFlexNoBlock", ...
                {@() schemaFlexNoBlock(1, 2), ...
                 @() schemaFlexNoBlock(1, 2, 3, 4, 5)}, ...
                encoding="JSON");

            import prodserver.mcp.internal.ParameterKind
            sig = defs.signatures.schemaFlexNoBlock.input;
            kinds = ParameterKind(sig.kind);
            test.verifyEqual(kinds(1), ParameterKind.Required);
            test.verifyEqual(kinds(2), ParameterKind.Required);
            test.verifyEqual(kinds(3), ParameterKind.Optional);
            test.verifyEqual(kinds(4), ParameterKind.Optional);
            test.verifyEqual(kinds(5), ParameterKind.Optional);
        end

    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
