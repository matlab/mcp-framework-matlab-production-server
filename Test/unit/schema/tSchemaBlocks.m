classdef tSchemaBlocks < matlab.unittest.TestCase
%tSchemaBlocks Test schema() with functions that have varying argument blocks.

% Copyright 2026 The MathWorks, Inc.

    properties
        toolsFolder
    end

    methods(TestClassSetup)
        function requireSchemaTools(test)
            rst = test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
            test.toolsFolder = rst.toolFolder;
        end
    end

    methods(Test)

        function fullBlocks(test)
            % Function with both input and output argument blocks.
            % Hand-written descriptions should be populated.
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() callWithOutputs(@schemaCompute, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding="JSON");

            % Input descriptions from comments
            test.verifyTrue(contains( ...
                defs.tools.inputSchema.properties.x.description, ...
                "First measurement"));
            test.verifyTrue(contains( ...
                defs.tools.inputSchema.properties.scale.description, ...
                "Scaling factor"));

            % Output descriptions from comments
            test.verifyTrue(contains( ...
                defs.tools.outputSchema.properties.total.description, ...
                "Sum of measurements"));

            % Types correct
            test.verifyEqual(defs.tools.inputSchema.properties.x.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.label.type, "string");
            test.verifyEqual(defs.tools.outputSchema.properties.report.type, "string");
        end

        function noBlocks(test)
            % Function with no argument blocks. Should not error.
            % Types come from observation; descriptions are auto-generated.
            defs = prodserver.mcp.schema("schemaComputeNoBlock", ...
                @() callWithOutputs(@schemaComputeNoBlock, 3, ...
                    {1.0, 2.0, 3.0}), ...
                encoding="JSON");

            % Should produce a valid definition without erroring
            test.verifyEqual(defs.tools.name, "schemaComputeNoBlock");

            % Input types from observation
            test.verifyEqual(defs.tools.inputSchema.properties.x.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.y.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.z.type, "number");

            % All inputs should have descriptions (auto-generated)
            test.verifyTrue(isfield(defs.tools.inputSchema.properties.x, 'description'));
            test.verifyTrue(strlength(defs.tools.inputSchema.properties.x.description) > 0);
        end

        function inputBlockOnly(test)
            % Function with input block but no output block.
            % Input descriptions from comments; output descriptions auto-generated.
            defs = prodserver.mcp.schema("schemaComputeInputOnly", ...
                @() callWithOutputs(@schemaComputeInputOnly, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding="JSON");

            % Input descriptions from hand-written comments
            test.verifyTrue(contains( ...
                defs.tools.inputSchema.properties.x.description, ...
                "First measurement"));

            % Output descriptions present (auto-generated)
            test.verifyTrue(isfield(defs.tools.outputSchema.properties.total, 'description'));
            test.verifyTrue(strlength( ...
                defs.tools.outputSchema.properties.total.description) > 0);

            % Output types from observation
            test.verifyEqual(defs.tools.outputSchema.properties.total.type, "number");
            test.verifyEqual(defs.tools.outputSchema.properties.report.type, "string");
        end

        function outputBlockOnly(test)
            % Function with output block but no input block.
            % Output descriptions from comments; input descriptions auto-generated.
            defs = prodserver.mcp.schema("schemaComputeOutputOnly", ...
                @() callWithOutputs(@schemaComputeOutputOnly, 3, ...
                    {1.0, 2.0, 3.0}), ...
                encoding="JSON");

            % Output descriptions from hand-written comments
            test.verifyTrue(contains( ...
                defs.tools.outputSchema.properties.total.description, ...
                "Sum of measurements"));

            % Input descriptions present (auto-generated)
            test.verifyTrue(isfield(defs.tools.inputSchema.properties.x, 'description'));
            test.verifyTrue(strlength( ...
                defs.tools.inputSchema.properties.x.description) > 0);

            % Input types from observation
            test.verifyEqual(defs.tools.inputSchema.properties.x.type, "number");
        end

        function nvpDetectedFromBlock(test)
            % NVP parameters detected as optional from input argument block.
            defs = prodserver.mcp.schema("schemaComputeInputOnly", ...
                @() callWithOutputs(@schemaComputeInputOnly, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding="JSON");

            % x, y, z are required
            test.verifyTrue(ismember("x", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("y", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("z", defs.tools.inputSchema.required));

            % scale, label are NVP (optional)
            test.verifyFalse(ismember("scale", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("label", defs.tools.inputSchema.required));
        end

        function autoDescriptionFormat(test)
            % Auto-generated descriptions include name expansion, type, and
            % status when metadata is available from argument blocks.
            defs = prodserver.mcp.schema("schemaComputeOutputOnly", ...
                @() callWithOutputs(@schemaComputeOutputOnly, 3, ...
                    {1.0, 2.0, 3.0}), ...
                encoding="JSON");

            % Input params have no block: auto-generated with just name
            descX = defs.tools.inputSchema.properties.x.description;
            test.verifyTrue(strlength(descX) > 0, ...
                "Auto-generated description should be non-empty");

            % Output params have a block: auto-generated with type info
            % (since output block provides Validation.Class/Size)
            % But output block has comments, so those are used instead.
            % Use input-only function's outputs for true auto-gen:
            defs2 = prodserver.mcp.schema("schemaComputeInputOnly", ...
                @() callWithOutputs(@schemaComputeInputOnly, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding="JSON");
            descTotal = defs2.tools.outputSchema.properties.total.description;
            test.verifyTrue(contains(descTotal, "Total") | ...
                contains(descTotal, "total"), ...
                "Auto-generated description should contain parameter name");
        end

        function toolDescriptionPopulated(test)
            % Tool-level description comes from H1 comment via metafunction.
            defs = prodserver.mcp.schema("schemaCompute", ...
                @() callWithOutputs(@schemaCompute, 3, ...
                    {1.0, 2.0, 3.0, 'scale', 2.0, 'label', "test"}), ...
                encoding="JSON");

            test.verifyTrue(contains(defs.tools.description, ...
                "summary statistics"));
        end

        function toolDescriptionNoBlock(test)
            % H1 comment available even without argument blocks.
            defs = prodserver.mcp.schema("schemaComputeNoBlock", ...
                @() callWithOutputs(@schemaComputeNoBlock, 3, ...
                    {1.0, 2.0, 3.0}), ...
                encoding="JSON");

            test.verifyTrue(contains(defs.tools.description, ...
                "summary statistics"));
        end

    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
