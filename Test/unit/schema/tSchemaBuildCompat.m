classdef tSchemaBuildCompat < matlab.unittest.TestCase
%tSchemaBuildCompat Verify schema() output is compatible with build().

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

        function passesValidation(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeToolDefinition(defs));
        end

        function passesValidationJSON(test)
            defs = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="JSON");
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeToolDefinition(defs));
        end

        function multiToolPassesValidation(test)
            defs = prodserver.mcp.schema( ...
                ["toyScalarOne","toyScalarTwo"], ...
                @() exerciseBoth(), encoding="Invertible");
            for i = 1:numel(defs)
                test.verifyWarningFree(...
                    @() prodserver.mcp.validation.mustBeToolDefinition(defs(i)));
            end
        end

        function structureHasRequiredFields(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            test.verifyTrue(isfield(defs.tools, 'name'));
            test.verifyTrue(isfield(defs.tools, 'description'));
            test.verifyTrue(isfield(defs.tools, 'inputSchema'));
            test.verifyTrue(isfield(defs.tools, 'outputSchema'));
            test.verifyTrue(isfield(defs, 'signatures'));
            test.verifyTrue(isfield(defs.signatures, 'schemaCompute'));
            test.verifyTrue(isfield(defs.signatures.schemaCompute, 'function'));
            test.verifyTrue(isfield(defs.signatures.schemaCompute, 'input'));
            test.verifyTrue(isfield(defs.signatures.schemaCompute, 'output'));
        end

        function inputSchemaHasProperties(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            test.verifyTrue(isfield(defs.tools.inputSchema, 'type'));
            test.verifyTrue(isfield(defs.tools.inputSchema, 'properties'));
            test.verifyTrue(isfield(defs.tools.inputSchema, 'required'));
        end

        function outputSchemaHasProperties(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            test.verifyTrue(isfield(defs.tools.outputSchema, 'type'));
            test.verifyTrue(isfield(defs.tools.outputSchema, 'properties'));
            test.verifyTrue(isfield(defs.tools.outputSchema, 'required'));
        end

        function requiredIsCellOfChar(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            req = defs.tools.inputSchema.required;
            test.verifyTrue(iscell(req), "required should be cell array");
            for i = 1:numel(req)
                test.verifyTrue(ischar(req{i}), ...
                    "Each required element should be char");
            end
        end

        function signaturesHaveKindAndOrder(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            inSig = defs.signatures.schemaCompute.input;
            test.verifyTrue(isfield(inSig, 'kind'));
            test.verifyTrue(isfield(inSig, 'order'));
            test.verifyTrue(isfield(inSig, 'group'));
            test.verifyTrue(isfield(inSig, 'validation'));
            test.verifyTrue(isfield(inSig, 'default'));
        end

        function wireEncodingWrapped(test)
            defs = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="Invertible");
            param = defs.tools.inputSchema.properties.x;
            test.verifyEqual(string(param.type), "object");
            test.verifyTrue(isfield(param, 'required'));
            test.verifyTrue(isfield(param, 'properties'));
            test.verifyTrue(isfield(param.properties, 'type'));
            test.verifyTrue(isfield(param.properties, 'size'));
            test.verifyTrue(isfield(param.properties, 'data'));
        end

        function wireEncodingToolDescription(test)
            defs = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="Invertible");
            test.verifyTrue(contains(defs.tools.description, ...
                prodserver.mcp.MCPConstants.WireEncodingResourceURI));
        end

        function jsonEncodingNoWrapper(test)
            defs = prodserver.mcp.schema("toyScalarOne", ...
                @() exerciseToyScalarOne(), encoding="JSON");
            param = defs.tools.inputSchema.properties.x;
            test.verifyFalse(isfield(param, 'properties'), ...
                "JSON encoding should not have wire encoding wrapper");
            test.verifyTrue(isfield(param, 'type'));
        end

        function minMaxPropertiesPresent(test)
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() exerciseSchemaCompute(), encoding="Invertible");
            test.verifyTrue(isfield(defs.tools.inputSchema, 'minProperties'));
            test.verifyTrue(isfield(defs.tools.inputSchema, 'maxProperties'));
        end

        function structuredTypePassesValidation(test)
            defs = prodserver.mcp.schema("schemaComplexNoBlock", ...
                @() exerciseComplex(), encoding="Invertible");
            test.verifyWarningFree(...
                @() prodserver.mcp.validation.mustBeToolDefinition(defs));
        end

        function structuredTypeMultiTool(test)
            defs = prodserver.mcp.schema( ...
                ["schemaDatetimeNoBlock","schemaDurationNoBlock"], ...
                @() exerciseDatetimeDuration(), encoding="Invertible");
            for i = 1:numel(defs)
                test.verifyWarningFree(...
                    @() prodserver.mcp.validation.mustBeToolDefinition(defs(i)));
            end
        end

    end
end

function exerciseSchemaCompute()
    [~,~,~] = schemaCompute(1.0, 2.0, 3.0, scale=2.0, label="test");
end

function exerciseToyScalarOne()
    [~] = toyScalarOne(42.0);
end

function exerciseBoth()
    [~] = toyScalarOne(42.0);
    [~,~] = toyScalarTwo("hello world", 3.0);
end

function exerciseComplex()
    [~,~,~] = schemaComplexNoBlock([3,0], [4,1]);
end

function exerciseDatetimeDuration()
    [~,~,~] = schemaDatetimeNoBlock(2026, 3, 15);
    [~,~] = schemaDurationNoBlock(1, 30, 45);
end
