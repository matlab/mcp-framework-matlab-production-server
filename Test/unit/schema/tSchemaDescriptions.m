classdef tSchemaDescriptions < matlab.unittest.TestCase
%tSchemaDescriptions Verify parameter descriptions on the example path.
%   A parameter without an arguments-block comment takes its description
%   from a help-text line ("name: text" or "name - text"), else from one
%   generated from its name and declaration. The tool description leaves
%   out the help-text lines that became parameter descriptions.

% Copyright 2026 The MathWorks, Inc.

    methods(TestClassSetup)
        function requireSchemaTools(test)
            test.applyFixture(...
                prodserver.mcp.test.mixin.RequireSchemaTools());
        end
    end

    methods(Test)

        function helpTextLinesDescribeParameters(test)
            % build warns if any input or output has no assigned type. But
            % that's not what we're testing here, so turn off that warning.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));

            defs = prodserver.mcp.schema("schemaHelpParams", ...
                @() schemaHelpParams(1:5, 2, 1), encoding="JSON");
            in = defs.tools.inputSchema.properties;
            out = defs.tools.outputSchema.properties;
            test.verifyEqual(in.signal.description, "samples to smooth");
            % A deeper-indented line continues the description; the next
            % parameter's line doesn't.
            test.verifyEqual(in.windowSize.description, ...
                "window length, in samples");
            test.verifyEqual(in.N.description, ...
                "iterations. Higher numbers smooth more.");
            % Names match without regard to case.
            test.verifyEqual(out.out.description, "the smoothed signal");
            test.verifyEqual(out.BBOX.description, "a bounding box");
        end

        function toolDescriptionLeavesOutUsedLines(test)
            % build warns if any input or output has no assigned type. But
            % that's not what we're testing here, so turn off that warning.
            test.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "prodserver:mcp:UnobservedParameters"));
            
            defs = prodserver.mcp.schema("schemaHelpParams", ...
                @() schemaHelpParams(1:5, 2, 1), encoding="JSON");
            % "type:" names no parameter, so it stays.
            test.verifyEqual(string(defs.tools.description), ...
                "Smooth a signal with a moving average. type: not a parameter");
        end

        function blockCommentWins(test)
            defs = prodserver.mcp.schema("schemaHelpAndBlock", ...
                @() schemaHelpAndBlock(1, 2), encoding="JSON");
            in = defs.tools.inputSchema.properties;
            test.verifyEqual(in.a.description, "First addend");
            test.verifyEqual(in.b.description, ...
                "the second number, from the help text");
            % Only the line that became a description leaves the tool
            % description.
            test.verifySubstring(defs.tools.description, ...
                "a: the first number, from the help text");
            test.verifyFalse(contains(defs.tools.description, ...
                "the second number"));
        end

        function declaredPathUnchanged(test)
            % Without examples, block comments are required and the tool
            % description keeps every help line.
            defs = prodserver.mcp.internal.mcpDefinition( ...
                "schemaHelpDeclared", "schemaHelpDeclared", encoding="JSON");
            test.verifySubstring(defs.tools.description, ...
                "a: the first number, from the help text");
            test.verifySubstring(defs.tools.description, ...
                "b: the second number, from the help text");
            test.verifyEqual( ...
                defs.tools.inputSchema.properties.b.description, ...
                "Second addend");
        end

        function declaredPathStillRequiresBlockComments(test)
            % A help-text line doesn't satisfy the strict declared path.
            test.verifyError(@() prodserver.mcp.internal.mcpDefinition( ...
                "schemaHelpAndBlock", "schemaHelpAndBlock", ...
                encoding="JSON"), ...
                "prodserver:mcp:ArgumentDescriptionMissing");
        end

        function generatedDescriptions(test)
            defs = prodserver.mcp.schema("schemaNoComments", ...
                @() schemaNoComments(3, 1, 2, "u", 4, [1 2]), ...
                encoding="JSON");
            in = defs.tools.inputSchema.properties;
            test.verifyEqual(in.windowSize.description, "Input window size.");
            % One-character names keep their case: x and X stay distinct.
            test.verifyEqual(in.x.description, "Input x.");
            test.verifyEqual(in.X.description, "Input X.");
            % Acronyms stay whole; abbreviations expand.
            test.verifyEqual(in.noisyURL.description, "Input noisy URL.");
            test.verifyEqual(in.num_points.description, ...
                "Input number of points.");
            test.verifyEqual(in.BBOX.description, "Input BBOX.");
            test.verifyEqual(defs.tools.outputSchema.properties.y.description, ...
                "Output y.");
        end

        function generatedNeverClaimsRequiredness(test)
            % The schema's required list says which inputs are required.
            defs = prodserver.mcp.schema("schemaNoComments", ...
                @() schemaNoComments(3, 1, 2, "u", 4, [1 2]), ...
                encoding="JSON");
            for io = ["inputSchema", "outputSchema"]
                p = defs.tools.(io).properties;
                for n = string(fieldnames(p))'
                    test.verifyFalse(contains(p.(n).description, ...
                        ["(required)", "(optional)"]), io + "." + n);
                end
            end
        end

        function generatedFromDeclaration(test)
            defs = prodserver.mcp.schema("schemaNoCommentsBlock", ...
                @() schemaNoCommentsBlock(1, [1 2]), encoding="JSON");
            in = defs.tools.inputSchema.properties;
            test.verifyEqual(in.x.description, "Input x: scalar double.");
            test.verifyEqual(in.v.description, ...
                "Input v: row vector of double.");
        end

    end
end
