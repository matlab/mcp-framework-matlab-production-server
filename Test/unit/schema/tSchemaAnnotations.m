classdef tSchemaAnnotations < matlab.unittest.TestCase
%tSchemaAnnotations Test %#schema injection via the observer (schema()) path.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function replaceSchemaApplied(test)
            % %#schema (replace) overrides the observed type completely.
            defs = prodserver.mcp.schema("schemaAnnotated", ...
                @() callWithOutputs(@schemaAnnotated, 2, ...
                    {struct('name','a','mode','fast'), [1;2;3], 1.5}), ...
                encoding="JSON");

            % config uses Replace schema: type should be "object"
            configSchema = defs.tools.inputSchema.properties.config;
            test.verifyTrue(configSchema.type == "object");
            test.verifyTrue(isfield(configSchema, 'properties'));
            test.verifyTrue(isfield(configSchema.properties, 'name'));
            test.verifyTrue(isfield(configSchema.properties, 'mode'));
        end

        function additiveSchemaApplied(test)
            % %#schema + adds properties to the observed type.
            defs = prodserver.mcp.schema("schemaAnnotated", ...
                @() callWithOutputs(@schemaAnnotated, 2, ...
                    {struct('name','a','mode','fast'), [1;2;3], 1.5}), ...
                encoding="JSON");

            % values uses Add schema: should retain array type and add minItems
            valuesSchema = defs.tools.inputSchema.properties.values;
            test.verifyEqual(valuesSchema.type, "array");
            test.verifyEqual(valuesSchema.minItems, 1);
        end

        function additiveOutputSchemaApplied(test)
            % %#schema + on output adds properties to observed output type.
            defs = prodserver.mcp.schema("schemaAnnotated", ...
                @() callWithOutputs(@schemaAnnotated, 2, ...
                    {struct('name','a','mode','fast'), [1;2;3;4;5], 2.0}), ...
                encoding="JSON");

            % result uses Add schema: should have minItems
            resultSchema = defs.tools.outputSchema.properties.result;
            test.verifyEqual(resultSchema.minItems, 0);
        end

        function unannotatedParamUnchanged(test)
            % Parameters without %#schema retain their observed schema.
            defs = prodserver.mcp.schema("schemaAnnotated", ...
                @() callWithOutputs(@schemaAnnotated, 2, ...
                    {struct('name','a','mode','fast'), [1;2;3], 1.5}), ...
                encoding="JSON");

            % threshold has no %#schema — should be scalar double -> number
            threshSchema = defs.tools.inputSchema.properties.threshold;
            test.verifyEqual(threshSchema.type, "number");

            % count has no %#schema — uint32 scalar -> integer
            countSchema = defs.tools.outputSchema.properties.count;
            test.verifyEqual(countSchema.type, "integer");
        end

        function conflictScalarMaxItemsErrors(test)
            % Scalar arg block + %#schema with maxItems should error.
            test.verifyError(...
                @() prodserver.mcp.schema("schemaConflict", ...
                    @() callWithOutputs(@schemaConflict, 1, {42.0}), ...
                    encoding="JSON"), ...
                "prodserver:mcp:SchemaConflict");
        end

        function introspectionPathConflictErrors(test)
            % Same conflict through the introspection path.
            test.verifyError(...
                @() prodserver.mcp.internal.defineForMCP( ...
                    "schemaConflict", "schemaConflict", encoding="JSON"), ...
                "prodserver:mcp:SchemaConflict");
        end

    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
