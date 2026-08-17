classdef tSchemaParams < matlab.unittest.TestCase
%tSchemaParams Integration tests for prodserver.mcp.schema with parameter tools.

% Copyright 2026 The MathWorks, Inc.

    properties
        toolsFolder
    end

    methods(TestClassSetup)
        function requireParamTools(test)
            rpt = test.applyFixture(...
                prodserver.mcp.test.mixin.RequireParamTools());
            test.toolsFolder = rpt.toolFolder;
        end
    end

    methods(Test)

        function allRequired(test)
            defs = prodserver.mcp.schema("threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1, 2, 3, 4}), ...
                encoding="JSON");
            % All 4 inputs should be required
            test.verifyEqual(numel(defs.tools.inputSchema.required), 4);
            test.verifyTrue(all(ismember(["a","b","c","d"], ...
                defs.tools.inputSchema.required)));
        end

        function allOptional(test)
            defs = prodserver.mcp.schema("allInOptional", ...
                @() callWithOutputs(@allInOptional, 3, {1, 2, 3, 4}), ...
                encoding="JSON");
            % allInOptional has all optional positional args → none required
            test.verifyTrue(~isfield(defs.tools.inputSchema, 'required') || ...
                isempty(defs.tools.inputSchema.required));
            % But all should appear in properties
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'a'));
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'b'));
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'c'));
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'd'));
        end

        function mixedNVP(test)
            defs = prodserver.mcp.schema("someInNVP", ...
                @() callWithOutputs(@someInNVP, 3, {1, 2, 'c', 3, 'd', 4}), ...
                encoding="JSON");
            % a, b are required positional; c, d are NVP (optional)
            test.verifyTrue(ismember("a", defs.tools.inputSchema.required));
            test.verifyTrue(ismember("b", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("c", defs.tools.inputSchema.required));
            test.verifyFalse(ismember("d", defs.tools.inputSchema.required));
            % All should have type number
            test.verifyEqual(defs.tools.inputSchema.properties.c.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.d.type, "number");
        end

        function multipleOutputs(test)
            defs = prodserver.mcp.schema("threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1, 2, 3, 4}), ...
                encoding="JSON");
            % 3 outputs: x, y, z
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'x'));
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'y'));
            test.verifyTrue(isfield(defs.tools.outputSchema.properties, 'z'));
        end

        function correctTypes(test)
            defs = prodserver.mcp.schema("threeFour", ...
                @() callWithOutputs(@threeFour, 3, {1.0, 2.0, 3.0, 4.0}), ...
                encoding="JSON");
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.b.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.c.type, "number");
            test.verifyEqual(defs.tools.inputSchema.properties.d.type, "number");
        end

        function multipleExercisesSameType(test)
            defs = prodserver.mcp.schema("threeFour", ...
                {@() callWithOutputs(@threeFour, 3, {1, 2, 3, 4}), ...
                 @() callWithOutputs(@threeFour, 3, {10, 20, 30, 40})}, ...
                encoding="JSON");
            % Multiple exercises, same types → deduplicated
            test.verifyEqual(defs.tools.inputSchema.properties.a.type, "number");
            test.verifyFalse(isfield(defs.tools.inputSchema.properties.a, 'anyOf'));
        end

        function nvpNotAllProvided(test)
            % Only provide some NVPs — others should still appear in schema
            % from metafunction metadata
            defs = prodserver.mcp.schema("someInNVP", ...
                @() callWithOutputs(@someInNVP, 3, {1, 2, 'c', 3}), ...
                encoding="JSON");
            % 'd' is declared in function but not exercised
            test.verifyTrue(isfield(defs.tools.inputSchema.properties, 'd'));
            % 'c' was exercised → has observed type
            test.verifyEqual(defs.tools.inputSchema.properties.c.type, "number");
        end

    end
end

function callWithOutputs(fcn, nout, args)
    [varargout{1:nout}] = fcn(args{:}); %#ok<VARARG>
end
