classdef tSchemaSizePrecedence < matlab.unittest.TestCase
%tSchemaSizePrecedence Verify argument block size takes precedence over observed size.
%
%   When an argument block declares a general size (e.g., (:,1)) and an
%   example call produces a specific size (e.g., a 5-element vector), the
%   generated schema must use the argument block's general constraint, not
%   the observed specific size.
%
%   When an argument block declares a fixed size (e.g., (1,3)), the schema
%   must include maxItems from the argument block even when the observation
%   path generates the schema.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function unrestrictedSizeNoMaxItems(test)
            % (:,1) double argument + observed 5-element vector.
            % Schema must NOT have maxItems because the argument block
            % allows any column length.
            defs = prodserver.mcp.schema("schemaColumnVector", ...
                @() callWithOutputs(@schemaColumnVector, 1, ...
                    {[10; 20; 30; 40; 50], 25.0}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.measurements;
            test.verifyEqual(prop.type, "array", ...
                "Unrestricted column vector should be an array.");
            test.verifyFalse(isfield(prop, 'maxItems'), ...
                "Unrestricted size (:,1) must not produce maxItems.");
        end

        function fixedSizeProducesMaxItems(test)
            % (1,3) double argument + observed 3-element vector.
            % Schema must have maxItems=3 from the argument block.
            defs = prodserver.mcp.schema("schemaFixedVector", ...
                @() callWithOutputs(@schemaFixedVector, 1, ...
                    {[120, -50, 80], "max"}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.stressState;
            test.verifyEqual(prop.type, "array", ...
                "Fixed-size vector should be an array.");
            test.verifyTrue(isfield(prop, 'maxItems'), ...
                "Fixed size (1,3) must produce maxItems in schema.");
            test.verifyEqual(prop.maxItems, 3, ...
                "maxItems should equal product of fixed dimensions.");
            test.verifyEqual(prop.minItems, 3, ...
                "A fixed size is an exact count, so minItems = maxItems.");
        end

        function fixedSizeWithoutExampleProducesMinItems(test)
            % (1,3) double argument, definition from the argument block.
            defs = prodserver.mcp.internal.mcpDefinition( ...
                "schemaFixedVector", "schemaFixedVector", encoding="JSON");

            prop = defs.tools.inputSchema.properties.stressState;
            test.verifyEqual(prop.type, "array");
            test.verifyEqual(prop.minItems, 3);
            test.verifyEqual(prop.maxItems, 3);
        end

        function unrestrictedSizeScalarExampleIsArray(test)
            % (:,1) double argument + observed scalar. The declared size
            % admits many elements, so the schema must be an array.
            defs = prodserver.mcp.schema("schemaColumnVector", ...
                @() callWithOutputs(@schemaColumnVector, 1, {5, 1}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.measurements;
            test.verifyEqual(prop.type, "array");
            test.verifyEqual(prop.items.type, "number");
            test.verifyFalse(isfield(prop, 'minItems'));
            test.verifyFalse(isfield(prop, 'maxItems'));
        end

        function unrestrictedSizeMixedExamplesIsArray(test)
            % (:,1) double argument + one scalar and one vector example.
            % The two observations merge into one array of numbers.
            defs = prodserver.mcp.schema("schemaColumnVector", ...
                {@() callWithOutputs(@schemaColumnVector, 1, {5, 1}), ...
                 @() callWithOutputs(@schemaColumnVector, 1, ...
                    {[1; 2; 3], 1})}, ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.measurements;
            test.verifyEqual(prop.type, "array");
            test.verifyEqual(prop.items.type, "number");
        end

        function structColumnScalarExampleIsArrayOfObjects(test)
            % (:,1) struct argument + observed scalar struct.
            defs = prodserver.mcp.schema("schemaStructColumn", ...
                @() callWithOutputs(@schemaStructColumn, 1, ...
                    {struct('name', 'steel', 'E', 200e9)}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.materials;
            test.verifyEqual(prop.type, "array");
            test.verifyEqual(prop.items.type, "object");
            test.verifyEqual(prop.items.properties.name.type, "string");
            test.verifyEqual(prop.items.properties.E.type, "number");
        end

        function structColumnArrayExampleKeepsFields(test)
            % (:,1) struct argument + observed 2-element struct array.
            s = [struct('name', 'a', 'E', 1); struct('name', 'b', 'E', 2)];
            defs = prodserver.mcp.schema("schemaStructColumn", ...
                @() callWithOutputs(@schemaStructColumn, 1, {s}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.materials;
            test.verifyEqual(prop.type, "array");
            test.verifyEqual(prop.items.properties.name.type, "string");
            test.verifyEqual(prop.items.properties.E.type, "number");
        end

        function charRowIsString(test)
            % (1,:) char argument is one string, not an array.
            defs = prodserver.mcp.schema("schemaCharRow", ...
                @() callWithOutputs(@schemaCharRow, 1, {'steel'}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.label;
            test.verifyEqual(prop.type, "string");
            test.verifyFalse(isfield(prop, 'items'));
        end

        function scalarFromBlockIsScalar(test)
            % (1,1) double argument remains scalar, not array.
            defs = prodserver.mcp.schema("schemaFixedVector", ...
                @() callWithOutputs(@schemaFixedVector, 1, ...
                    {[120, -50, 80], "max"}), ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.component;
            test.verifyEqual(prop.type, "string", ...
                "Scalar string argument should have type 'string'.");
            test.verifyFalse(isfield(prop, 'items'), ...
                "Scalar argument should not have 'items' field.");
        end

        function unrestrictedSizeMultipleObservations(test)
            % Multiple observations with different vector lengths.
            % Schema must still not have maxItems.
            defs = prodserver.mcp.schema("schemaColumnVector", ...
                {@() callWithOutputs(@schemaColumnVector, 1, ...
                    {[10; 20; 30], 5.0}), ...
                 @() callWithOutputs(@schemaColumnVector, 1, ...
                    {[1; 2; 3; 4; 5; 6; 7; 8], 3.0})}, ...
                encoding="JSON");

            prop = defs.tools.inputSchema.properties.measurements;
            test.verifyEqual(prop.type, "array");
            test.verifyFalse(isfield(prop, 'maxItems'), ...
                "Unrestricted (:,1) must never produce maxItems, " + ...
                "regardless of observed lengths.");
        end

        function fixedSizeOutputScalar(test)
            % Output declared as (1,1) double should be scalar in schema.
            defs = prodserver.mcp.schema("schemaColumnVector", ...
                @() callWithOutputs(@schemaColumnVector, 1, ...
                    {[10; 20; 30; 40; 50], 25.0}), ...
                encoding="JSON");

            prop = defs.tools.outputSchema.properties.mag;
            test.verifyEqual(prop.type, "number", ...
                "Output declared (1,1) double should be scalar number.");
        end

    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
