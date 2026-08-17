classdef tSchemaRoundTrip < matlab.unittest.TestCase
%tSchemaRoundTrip Verify schema() produces structurally equivalent output
%   to mcpDefinition() for functions with full argument blocks.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end

        function requireToyTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireToyTools());
        end
    end

    methods(Test)

        function scalarTypeEquivalence(test)
            observed = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarOne", "toyScalarOne", encoding="Invertible");

            % Input x: scalar double wrapped in wire encoding
            obsX = observed.tools.inputSchema.properties.x;
            expX = expected.tools.inputSchema.properties.x;
            verifyWireEncodedType(test, obsX, expX, "input.x");

            % Output y: scalar double wrapped
            obsY = observed.tools.outputSchema.properties.y;
            expY = expected.tools.outputSchema.properties.y;
            verifyWireEncodedType(test, obsY, expY, "output.y");
        end

        function multiParamTypeEquivalence(test)
            observed = prodserver.mcp.schema("toyScalarTwo", ...
                @() exerciseToyScalarTwo(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarTwo", "toyScalarTwo", encoding="Invertible");

            % Input s: string
            verifyWireEncodedType(test, ...
                observed.tools.inputSchema.properties.s, ...
                expected.tools.inputSchema.properties.s, "input.s");

            % Input n: double
            verifyWireEncodedType(test, ...
                observed.tools.inputSchema.properties.n, ...
                expected.tools.inputSchema.properties.n, "input.n");

            % Output cs: string
            verifyWireEncodedType(test, ...
                observed.tools.outputSchema.properties.cs, ...
                expected.tools.outputSchema.properties.cs, "output.cs");

            % Output d: double
            verifyWireEncodedType(test, ...
                observed.tools.outputSchema.properties.d, ...
                expected.tools.outputSchema.properties.d, "output.d");
        end

        function nvpEquivalence(test)
            observed = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() exerciseToyScalarNVOptions(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarNVOptions", "toyScalarNVOptions", encoding="Invertible");

            % NVP 'mpg' should be present and typed
            verifyWireEncodedType(test, ...
                observed.tools.inputSchema.properties.mpg, ...
                expected.tools.inputSchema.properties.mpg, "input.mpg");

            % NVP 'make' should be present and typed
            verifyWireEncodedType(test, ...
                observed.tools.inputSchema.properties.make, ...
                expected.tools.inputSchema.properties.make, "input.make");
        end

        function requiredArraysMatch(test)
            observed = prodserver.mcp.schema("toyScalarTwo", ...
                @() exerciseToyScalarTwo(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarTwo", "toyScalarTwo", encoding="Invertible");

            obsReq = sort(string(observed.tools.inputSchema.required));
            expReq = sort(string(expected.tools.inputSchema.required));
            test.verifyEqual(obsReq, expReq, "Input required mismatch");

            obsReq = sort(string(observed.tools.outputSchema.required));
            expReq = sort(string(expected.tools.outputSchema.required));
            test.verifyEqual(obsReq, expReq, "Output required mismatch");
        end

        function signaturesKindMatch(test)
            observed = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() exerciseToyScalarNVOptions(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarNVOptions", "toyScalarNVOptions", encoding="Invertible");

            test.verifyEqual( ...
                observed.signatures.toyScalarNVOptions.input.kind, ...
                expected.signatures.toyScalarNVOptions.input.kind);
        end

        function signaturesOrderMatch(test)
            observed = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() exerciseToyScalarNVOptions(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarNVOptions", "toyScalarNVOptions", encoding="Invertible");

            test.verifyEqual( ...
                observed.signatures.toyScalarNVOptions.input.order, ...
                expected.signatures.toyScalarNVOptions.input.order);
        end

        function signaturesGroupMatch(test)
            observed = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() exerciseToyScalarNVOptions(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarNVOptions", "toyScalarNVOptions", encoding="Invertible");

            test.verifyEqual( ...
                observed.signatures.toyScalarNVOptions.input.group, ...
                expected.signatures.toyScalarNVOptions.input.group);
        end

        function toolDescriptionsMatch(test)
            observed = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarOne", "toyScalarOne", encoding="Invertible");

            test.verifyEqual(observed.tools.description, ...
                expected.tools.description, "Tool description mismatch");
        end

        function paramDescriptionsMatch(test)
            observed = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarOne", "toyScalarOne", encoding="Invertible");

            % Compare description of input parameter x
            obsDesc = observed.tools.inputSchema.properties.x.description;
            expDesc = expected.tools.inputSchema.properties.x.description;
            test.verifyEqual(obsDesc, expDesc, "Parameter description mismatch");
        end

        function minMaxPropertiesMatch(test)
            observed = prodserver.mcp.schema("toyScalarNVOptions", ...
                @() exerciseToyScalarNVOptions(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "toyScalarNVOptions", "toyScalarNVOptions", encoding="Invertible");

            test.verifyEqual( ...
                observed.tools.inputSchema.minProperties, ...
                expected.tools.inputSchema.minProperties, ...
                "minProperties mismatch");
            test.verifyEqual( ...
                observed.tools.inputSchema.maxProperties, ...
                expected.tools.inputSchema.maxProperties, ...
                "maxProperties mismatch");
        end

        function fullSchemaCompute(test)
            observed = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            expected = prodserver.mcp.internal.mcpDefinition( ...
                "schemaCompute", "schemaCompute", encoding="Invertible");

            % Full structural comparison of input and output schemas
            test.verifyEqual( ...
                observed.tools.inputSchema, ...
                expected.tools.inputSchema, ...
                "inputSchema structural mismatch");
            test.verifyEqual( ...
                observed.tools.outputSchema, ...
                expected.tools.outputSchema, ...
                "outputSchema structural mismatch");
        end

    end

    methods(Access = private)

        function verifyWireEncodedType(test, obs, exp, label)
        %verifyWireEncodedType Compare wire-encoded parameter structures.
            % Both should be wire encoding objects
            test.verifyEqual(obs.type, exp.type, label + ": wrapper type");

            % Compare the data field type
            if isfield(obs, 'properties') && isfield(obs.properties, 'data')
                obsData = obs.properties.data;
                expData = exp.properties.data;
                test.verifyEqual(obsData.type, expData.type, ...
                    label + ": data type");
                if isfield(obsData, 'items') && isfield(expData, 'items')
                    test.verifyEqual(obsData.items.type, expData.items.type, ...
                        label + ": items type");
                end
            else
                test.verifyEqual(obs.type, exp.type, label + ": bare type");
            end
        end

    end
end

function exerciseToyScalarOne()
    [~] = toyScalarOne(42.0);
end

function exerciseToyScalarTwo()
    [~,~] = toyScalarTwo("hello world", 3.0);
end

function exerciseToyScalarNVOptions()
    [~] = toyScalarNVOptions(2024.0, mpg=3.49, range=4000.0, ...
        make="Lockheed", model="Electra");
end

function exerciseSchemaCompute()
    [~,~,~] = schemaCompute(1.0, 2.0, 3.0, scale=2.0, label="test");
end
